#!/usr/bin/env bash
# ciq_local_smoke_v1.sh
# Boots each detected FastAPI service (with a main.py) on an ephemeral port,
# curls /health (fallback /), reports PASS/FAIL, then cleans up.
# Non-invasive: uses a throwaway venv under .smoke/.venv-<hash> per service.

set -Eeuo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT="ops/swarm/local_smoke_${TS}.txt"
mkdir -p ops/swarm

say(){ echo "$*" | tee -a "$REPORT"; }
hdr(){ printf '%*s\n' 100 | tr ' ' '=' | tee -a "$REPORT"; echo "$*" | tee -a "$REPORT"; printf '%*s\n' 100 | tr ' ' '=' | tee -a "$REPORT"; }

# find services that look bootable (have main.py)
mapfile -t SRVS < <(find services -maxdepth 2 -type f -name main.py -printf '%h\n' | sort -u)

hdr "CONSTRUCT-IQ :: LOCAL SMOKE RUN — ${TS}"
say "[i] repo: $ROOT"
say "[i] services to test: ${#SRVS[@]}"

# helper: choose a free port via Python
pick_port(){ python3 - <<'PY'
import socket
s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()
PY
}

# boot one service, curl health, tear down
test_service(){
  local dir="$1"
  local name="${dir#services/}"
  local vdir=".smoke/.venv-$(echo -n "$dir" | sha1sum | awk '{print $1}')"

  say ""
  say "[*] ${name}"

  # ensure venv
  python3 -m venv "$vdir" >/dev/null 2>&1 || true
  # shellcheck disable=SC1091
  source "$vdir/bin/activate"
  pip -q install --upgrade pip >/dev/null 2>&1 || true

  # deps
  if [[ -f "$dir/requirements.txt" ]]; then
    pip -q install -r "$dir/requirements.txt" >/dev/null 2>&1 || true
  else
    pip -q install fastapi "uvicorn[standard]" >/dev/null 2>&1 || true
  fi

  # sanity: FastAPI?
  if ! python - <<'PY' "$dir"; then
import sys, re, pathlib
p = pathlib.Path(sys.argv[1]).joinpath("main.py")
t = p.read_text(encoding="utf-8", errors="ignore")
print("FASTAPI" if re.search(r"FastAPI\\s*\\(", t) else "PY")
PY
  then
    say "    -> [WARN] could not inspect main.py"
  fi

  kind=$(python - <<'PY' "$dir"
import sys, re, pathlib
p = pathlib.Path(sys.argv[1]).joinpath("main.py")
t = p.read_text(encoding="utf-8", errors="ignore")
print("fastapi" if re.search(r"FastAPI\\s*\\(", t) else "python")
PY
)
  port="$(pick_port)"
  url="http://127.0.0.1:${port}"

  # start
  if [[ "$kind" == "fastapi" ]]; then
    cmd=(uvicorn main:app --host 127.0.0.1 --port "$port")
  else
    cmd=(python main.py)
  fi

  # run in background with cwd=$dir
  pushd "$dir" >/dev/null
  setsid bash -c "${cmd[*]} >/tmp/smoke_${port}.log 2>&1" &
  pid=$!
  popd >/dev/null

  # wait for boot (max ~10s)
  ok=false
  for i in {1..20}; do
    sleep 0.5
    if curl -fsS "$url/health" >/dev/null 2>&1 || curl -fsS "$url/" >/dev/null 2>&1; then
      ok=true; break
    fi
    # if process died, bail early
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
  done

  # read a bit of logs on failure
  if ! $ok; then
    say "    -> FAIL: no healthy response at ${url}/health (or /)"
    say "       tail logs:"
    tail -n 25 "/tmp/smoke_${port}.log" 2>/dev/null | sed 's/^/         /' | tee -a "$REPORT" || true
  else
    say "    -> PASS: ${url}"
  fi

  # cleanup
  kill "$pid" >/dev/null 2>&1 || true
  sleep 0.5
  kill -9 "$pid" >/dev/null 2>&1 || true

  # keep venv to speed up re-runs
  deactivate || true
}

# Pre-flight: confirm directories exist
if ((${#SRVS[@]}==0)); then
  say "[i] No services with main.py found under services/*"
  say "    Nothing to do."
  exit 0
fi

# Run tests
pass=0; fail=0
for d in "${SRVS[@]}"; do
  if test_service "$d"; then
    : # test_service always returns 0; PASS/FAIL logged inside
  fi
done

say ""
say "Report written to: ${REPORT}"
