#!/usr/bin/env bash
# ciq_local_smoke_v2.sh
# Boot each service with a main.py on a free port, probe /health (fallback /),
# write a pass/fail report, and tear it down. No global deps touched.

set -Eeuo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT="ops/swarm/local_smoke_${TS}.txt"
mkdir -p ops/swarm /tmp/ciq-smoke

say(){ echo "$*" | tee -a "$REPORT"; }
hr(){ printf '%*s\n' 100 | tr ' ' '=' | tee -a "$REPORT"; }

hr
say "CONSTRUCT-IQ :: LOCAL SMOKE RUN — ${TS}"
hr
say "[i] repo: $ROOT"

# discover services that have a main.py one or two levels down (services/* or services/*/*)
mapfile -t SRVS < <(find services -mindepth 1 -maxdepth 2 -type f -name main.py -printf '%h\n' | sort -u)
say "[i] services to test: ${#SRVS[@]}"
for s in "${SRVS[@]}"; do say "    - $s"; done

# helpers
pick_port() {
  python3 - <<'PY'
import socket
s = socket.socket()
s.bind(('',0))
print(s.getsockname()[1])
s.close()
PY
}

is_fastapi() {
  local dir="$1"
  python3 - "$dir" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])/"main.py"
try:
  t = p.read_text(encoding="utf-8", errors="ignore")
  print("yes" if re.search(r"FastAPI\s*\(", t) else "no")
except Exception:
  print("no")
PY
}

ensure_venv() {
  local vdir="$1"
  if [[ ! -d "$vdir" ]]; then
    python3 -m venv "$vdir" >/dev/null 2>&1 || true
  fi
  # shellcheck disable=SC1091
  source "$vdir/bin/activate"
  python3 -m pip -q install --upgrade pip >/dev/null 2>&1 || true
}

boot_and_probe() {
  local dir="$1"
  local name="${dir#services/}"
  local vdir=".smoke/.venv-$(echo -n "$dir" | sha1sum | awk '{print $1}')"
  local kind port url pid log

  say ""
  say "[*] ${name}"

  ensure_venv "$vdir"

  # deps: use service requirements.txt if present; otherwise install fastapi+uvicorn baseline
  if [[ -f "$dir/requirements.txt" ]]; then
    python3 -m pip -q install -r "$dir/requirements.txt" >/dev/null 2>&1 || true
  else
    python3 -m pip -q install fastapi "uvicorn[standard]" >/dev/null 2>&1 || true
  fi

  # detect kind
  kind="$(is_fastapi "$dir")"   # "yes" or "no"
  port="$(pick_port)"
  url="http://127.0.0.1:${port}"
  log="/tmp/ciq-smoke/${name//\//_}_${port}.log"

  pushd "$dir" >/dev/null
  if [[ "$kind" == "yes" ]]; then
    setsid bash -c "uvicorn main:app --host 127.0.0.1 --port ${port} >'${log}' 2>&1" &
  else
    setsid bash -c "python3 main.py >'${log}' 2>&1" &
  fi
  pid=$!
  popd >/dev/null

  # wait up to 10s for health
  ok=0
  for _ in {1..20}; do
    sleep 0.5
    if curl -fsS "${url}/health" >/dev/null 2>&1 || curl -fsS "${url}/" >/dev/null 2>&1; then
      ok=1; break
    fi
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      break
    fi
  done

  if [[ "$ok" -eq 1 ]]; then
    say "    -> PASS: ${url} (health ok)"
  else
    say "    -> FAIL: ${url} (no /health or / response)"
    say "       tail logs:"
    tail -n 40 "$log" 2>/dev/null | sed 's/^/         /' | tee -a "$REPORT" || true
  fi

  # cleanup
  kill "$pid" >/dev/null 2>&1 || true
  sleep 0.3
  kill -9 "$pid" >/dev/null 2>&1 || true

  # keep venv for faster re-runs
  deactivate || true
}

# hard preflight (useful on minimal crostini)
need=(python3 curl)
miss=()
for b in "${need[@]}"; do command -v "$b" >/dev/null 2>&1 || miss+=("$b"); done
if ((${#miss[@]})); then
  say "[!] missing tools: ${miss[*]}"; exit 2
fi

if ((${#SRVS[@]}==0)); then
  say "[i] No services with main.py found. Done."
  exit 0
fi

for d in "${SRVS[@]}"; do
  boot_and_probe "$d"
done

say ""
hr
say "Report: ${REPORT}"
