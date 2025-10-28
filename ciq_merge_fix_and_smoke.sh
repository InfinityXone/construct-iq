#!/usr/bin/env bash
# ciq_merge_fix_and_smoke.sh
# Analyze -> Auto-fix (optional) -> Local smoke test -> (optional) push

set -Eeuo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

FIX=1          # default: do fixes
PUSH=0         # push only if asked
for a in "$@"; do
  case "$a" in
    --no-fix) FIX=0 ;;
    --push) PUSH=1 ;;
    --help|-h) echo "Usage: $0 [--no-fix] [--push]"; exit 0 ;;
    *) echo "[warn] unknown flag: $a" ;;
  esac
done

TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT="ops/swarm/fix_and_smoke_${TS}.txt"
mkdir -p ops/swarm /tmp/ciq-smoke .smoke

say(){ echo "$*"; echo "$*" >> "$REPORT"; }
hr(){ printf '%*s\n' 100 | tr ' ' '=' | tee -a "$REPORT" >/dev/null; }

hr
say "CONSTRUCT-IQ :: MERGE FIX + SMOKE — $TS"
say "[i] repo: $ROOT"
say "[i] branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
say "[i] flags: FIX=$FIX PUSH=$PUSH"
hr

# ---------- 0) heal accidental gitlink ----------
if git ls-files -s _from_github 2>/dev/null | awk '{print $1}' | grep -q '^160000$'; then
  say "[!] _from_github is recorded as submodule/gitlink"
  if (( FIX )); then
    git rm --cached _from_github || true
    say "[✓] removed gitlink entry (directory will be normal files next commit)"
  fi
else
  [[ -d _from_github ]] && say "[i] _from_github present as normal directory (ok)"
fi

# ---------- 1) ensure key dirs exist ----------
NEEDED=(
  services services/memory-gateway services/orchestrator services/agents
  apps/swarm-dashboard ops/swarm infra/swarm docs/swarm .github/workflows
)
for d in "${NEEDED[@]}"; do
  if [[ ! -d "$d" ]]; then
    if (( FIX )); then mkdir -p "$d"; fi
    say "[${FIX:+~}${FIX:+=}] ensured dir: $d"
  fi
done

# ---------- 2) ignore runtime logs for memory-gateway ----------
if (( FIX )); then
  if ! grep -q 'services/memory-gateway/*LOG.txt' .gitignore 2>/dev/null; then
    printf "\n# memory-gateway runtime logs\nservices/memory-gateway/*LOG.txt\n" >> .gitignore
    say "[✓] updated .gitignore for memory-gateway logs"
  fi
  git rm --cached services/memory-gateway/*LOG.txt 2>/dev/null || true
fi

# ---------- 3) service detection ----------
mapfile -t SRVS < <(find services -mindepth 1 -maxdepth 2 -type f -name main.py -printf '%h\n' | sort -u)
if ((${#SRVS[@]}==0)); then
  say "[i] no services/main.py found under services/* (nothing to smoke)"
fi

detect_kind() {
  local d="$1"
  if grep -qE 'from[[:space:]]+flask[[:space:]]+import|import[[:space:]]+flask' "$d/main.py" 2>/dev/null; then
    echo "flask"; return
  fi
  if grep -qE 'FastAPI\s*\(' "$d/main.py" 2>/dev/null; then
    echo "fastapi"; return
  fi
  echo "plain"
}

ensure_requirements() {
  local d="$1" kind="$2"
  local req="$d/requirements.txt"
  if [[ -f "$req" ]]; then return 0; fi
  (( FIX )) || { say "    [~] missing requirements.txt"; return 0; }
  case "$kind" in
    fastapi)
      cat > "$req" <<'REQ'
fastapi
uvicorn[standard]
REQ
      ;;
    flask)
      cat > "$req" <<'REQ'
flask
gunicorn
REQ
      ;;
    *)
      cat > "$req" <<'REQ'
requests
REQ
      ;;
  esac
  say "    [✓] wrote requirements.txt for $kind"
}

ensure_dockerfile() {
  local d="$1" kind="$2"
  local df="$d/Dockerfile"
  if [[ -f "$df" ]]; then return 0; fi
  (( FIX )) || { say "    [~] missing Dockerfile"; return 0; }
  case "$kind" in
    fastapi)
      cat > "$df" <<'DOCK'
FROM python:3.11-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8080
CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8080"]
DOCK
      ;;
    flask)
      cat > "$df" <<'DOCK'
FROM python:3.11-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8080
# If app variable exists: gunicorn, else fallback to python main.py
CMD bash -lc 'python - <<PY
try:
  import main
  import os
  has_app = getattr(main, "app", None) is not None
  os.execvp("gunicorn", ["gunicorn","-b","0.0.0.0:8080","main:app"] if has_app else ["python","main.py"])
except Exception:
  import os; os.execvp("python",["python","main.py"])
PY'
DOCK
      ;;
    *)
      cat > "$df" <<'DOCK'
FROM python:3.11-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8080
CMD ["python","main.py"]
DOCK
      ;;
  esac
  say "    [✓] wrote Dockerfile for $kind"
}

py_compile_check() {
  local d="$1"
  python3 - <<'PY' "$d" 2>/dev/null && echo OK || echo FAIL
import sys, py_compile, pathlib
p = pathlib.Path(sys.argv[1])/"main.py"
py_compile.compile(str(p), doraise=True)
PY
}

hr
say "SERVICE PREP"
for d in "${SRVS[@]}"; do
  name="${d#services/}"
  kind="$(detect_kind "$d")"
  say "[*] $name  (kind=$kind)"
  ensure_requirements "$d" "$kind"
  ensure_dockerfile   "$d" "$kind"
  res="$(py_compile_check "$d")"
  if [[ "$res" == "OK" ]]; then
    say "    [✓] py-compile OK"
  else
    say "    [!] py-compile FAILED"
  fi
done

# ---------- 4) docs placeholders (only if missing) ----------
stub_doc() {
  local d="$1"
  [[ -f "$d/README.md" ]] && return 0
  (( FIX )) || { say "[~] missing $d/README.md"; return 0; }
  mkdir -p "$d"
  cat > "$d/README.md" <<EOF
# $(basename "$d")
This module was migrated/merged as part of the Infinity Swarm → Construct-IQ integration.
EOF
  say "[✓] created $d/README.md"
}
stub_doc "ops/swarm"; stub_doc "infra/swarm"; stub_doc "docs/swarm"

# ---------- 5) commit & optional push ----------
if (( FIX )); then
  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "chore: merge heal (remove gitlink, write reqs/Dockerfiles, docs stubs)" || true
    say "[✓] committed autofixes"
  else
    say "[i] nothing to commit"
  fi
fi
if (( PUSH )); then
  say "[i] pushing branch to origin…"
  git push -u origin "$(git rev-parse --abbrev-ref HEAD)" || true
fi

# ---------- 6) local smoke ----------
hr
say "LOCAL SMOKE TEST"

pick_port() { python3 - <<'PY'
import socket
s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()
PY
}

is_fastapi() {
  local d="$1"
  python3 - "$d" <<'PY'
import sys, pathlib, re
p=pathlib.Path(sys.argv[1])/"main.py"
try:
  t=p.read_text(encoding='utf-8',errors='ignore')
  print("yes" if re.search(r"FastAPI\s*\\(", t) else "no")
except Exception: print("no")
PY
}

need=(python3 curl)
miss=(); for b in "${need[@]}"; do command -v "$b" >/dev/null || miss+=("$b"); done
if ((${#miss[@]})); then
  say "[!] missing tools: ${miss[*]} — skipping smoke test"
  hr; say "Report: $REPORT"; exit 0
fi

if ((${#SRVS[@]}==0)); then
  say "[i] no services to boot — skipping smoke test"
  hr; say "Report: $REPORT"; exit 0
fi

for d in "${SRVS[@]}"; do
  name="${d#services/}"
  log="/tmp/ciq-smoke/${name//\//_}_$(date +%s).log"
  vdir=".smoke/.venv-$(echo -n "$d" | sha1sum | awk '{print $1}')"
  mkdir -p /tmp/ciq-smoke

  say ""
  say "[*] $name"

  python3 -m venv "$vdir" >/dev/null 2>&1 || true
  # shellcheck disable=SC1091
  source "$vdir/bin/activate"
  python3 -m pip -q install --upgrade pip >/dev/null 2>&1 || true
  if [[ -f "$d/requirements.txt" ]]; then
    python3 -m pip -q install -r "$d/requirements.txt" >/dev/null 2>&1 || true
  fi

  kind="$(is_fastapi "$d")"
  port="$(pick_port)"
  url="http://127.0.0.1:${port}"

  pushd "$d" >/dev/null
  if [[ "$kind" == "yes" ]]; then
    setsid bash -c "uvicorn main:app --host 127.0.0.1 --port ${port} >'${log}' 2>&1" &
  else
    setsid bash -c "python3 main.py >'${log}' 2>&1" &
  fi
  pid=$!
  popd >/dev/null

  ok=0
  for _ in {1..24}; do
    sleep 0.5
    if curl -fsS "$url/health" >/dev/null 2>&1 || curl -fsS "$url/" >/dev/null 2>&1; then ok=1; break; fi
    kill -0 "$pid" >/dev/null 2>&1 || break
  done

  if (( ok )); then
    say "    -> PASS: ${url}"
  else
    say "    -> FAIL: ${url} — last 50 log lines:"
    tail -n 50 "$log" 2>/dev/null | sed 's/^/         /' | tee -a "$REPORT" || true
  fi

  kill "$pid" >/dev/null 2>&1 || true
  sleep 0.3
  kill -9 "$pid" >/dev/null 2>&1 || true
  deactivate || true
done

hr
say "Report: $REPORT"
