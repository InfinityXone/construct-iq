# ~/construct-iq/fix_swarm_now.sh
#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$HOME/construct-iq}"
PUSH="${PUSH:-0}"          # set to 1 to git commit/push
SMOKE_SECS="${SMOKE_SECS:-8}"

cd "$ROOT" 2>/dev/null || { echo "run inside your construct-iq clone"; exit 1; }

echo "===================================================================================================="
echo "CONSTRUCT-IQ ⟂ SWARM — AUTO-FIX — $(date -u +%Y%m%dT%H%M%SZ)"
echo "===================================================================================================="
echo "[i] repo: $ROOT"

# ---------- 0) Hygiene: ignore logs & local venv ----------
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "[!] not a git repo"; exit 1; }

ensure_ignores() {
  local add=0
  grep -qE '^\.smoke/$' .gitignore || add=1
  grep -qE '^services/.+/\*LOG\.txt$' .gitignore || add=1
  if [[ "$add" -eq 1 ]]; then
    {
      echo ""
      echo "# local smoke env + runtime logs"
      echo ".smoke/"
      echo "services/*/*LOG.txt"
    } >> .gitignore
    echo "[✓] updated .gitignore"
  else
    echo "[✓] .gitignore already OK"
  fi
}
ensure_ignores

# ---------- 1) Kill stray gitlinks/submodules recorded by accident ----------
if [[ -f .gitmodules ]]; then
  echo "[!] found .gitmodules — removing accidental submodules"
  git submodule deinit -f --all || true
  git rm -f $(git config -f .gitmodules --name-only --get-regexp path | awk '{print $2}') || true
  rm -f .gitmodules || true
  echo "[✓] submodules cleaned"
fi

# Common accidental gitlink directory seen in your logs
if git ls-files --stage | awk '{print $2, $4}' | grep -qE '160000 .* _from_github$'; then
  echo "[!] _from_github recorded as gitlink — fixing"
  git rm --cached _from_github || true
  rm -rf _from_github/.git || true
  echo "[✓] removed gitlink entry"
fi

# ---------- 2) Patch broken shell header(s) causing “syntax error near )” ----------
# We’ll defensively fix line 1–5 for the known file; no harm if it’s already fine.
if [[ -f ops/swarm/ciq_merge_supercheck_v3.sh ]]; then
  tmp="$(mktemp)"
  awk 'NR==1{$0="#!/usr/bin/env bash"}1' ops/swarm/ciq_merge_supercheck_v3.sh \
    | sed -E '1,5 s/^\),?$//' \
    | sed -E '1,5 s/^\)+$//' > "$tmp"
  mv "$tmp" ops/swarm/ciq_merge_supercheck_v3.sh
  chmod +x ops/swarm/ciq_merge_supercheck_v3.sh
  echo "[✓] normalized ops/swarm/ciq_merge_supercheck_v3.sh shebang/early junk"
fi

# ---------- 3) Service scan & classify (FastAPI vs Flask) ----------
mapfile -t SERVICES < <(find services -maxdepth 1 -mindepth 1 -type d | sort)
if [[ "${#SERVICES[@]}" -eq 0 ]]; then
  echo "[!] no services/* directories found"; exit 1
fi

classify_service() {
  local dir="$1"
  local main_py
  # choose a main file: main.py or app.py
  if [[ -f "$dir/main.py" ]]; then main_py="$dir/main.py"
  elif [[ -f "$dir/app.py" ]]; then main_py="$dir/app.py"
  else
    echo "none"
    return
  fi
  if grep -q 'FastAPI' "$main_py"; then echo "fastapi"
  elif grep -q 'from flask' "$main_py" || grep -q 'import flask' "$main_py"; then echo "flask"
  else echo "unknown"
  fi
}

# ---------- 4) Write minimal reqs & Dockerfile per service ----------
write_fastapi_files() {
  local dir="$1"
  [[ -f "$dir/requirements.txt" ]] || cat > "$dir/requirements.txt" <<'REQ'
fastapi>=0.103
uvicorn[standard]>=0.23
python-dotenv>=1.0
REQ

  [[ -f "$dir/Dockerfile" ]] || cat > "$dir/Dockerfile" <<'DOCKER'
FROM python:3.11-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8080
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
# Assume main:app exists; adjust if your module is different.
CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8080"]
DOCKER
}

write_flask_files() {
  local dir="$1"
  [[ -f "$dir/requirements.txt" ]] || cat > "$dir/requirements.txt" <<'REQ'
flask>=3.0
gunicorn>=21.2
python-dotenv>=1.0
REQ

  [[ -f "$dir/Dockerfile" ]] || cat > "$dir/Dockerfile" <<'DOCKER'
FROM python:3.11-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8080
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
# Assume main:app or app:app. We try main:app first; override via GUNICORN_APP if needed.
ENV GUNICORN_APP=main:app
CMD ["bash","-lc","exec gunicorn --bind 0.0.0.0:${PORT} ${GUNICORN_APP}"]
DOCKER
}

# ---------- 5) Lightweight local smoke runner ----------
mkdir -p .smoke/logs
python3 -m venv .smoke/venv
source .smoke/venv/bin/activate
pip install --upgrade pip >/dev/null

smoke_one() {
  local dir="$1" kind="$2"
  local port
  port=$(python - <<'PY'
import socket,random
s=socket.socket(); 
while True:
  p=random.randint(20000,59999)
  try: s.bind(("127.0.0.1",p)); s.close(); print(p); break
  except OSError: pass
PY
)
  local log=".smoke/logs/$(basename "$dir").log"
  rm -f "$log"

  echo "    [-] installing deps for $(basename "$dir")"
  pip install -r "$dir/requirements.txt" >/dev/null

  echo "    [-] launching $(basename "$dir") on :$port"
  if [[ "$kind" == "fastapi" ]]; then
    # Try to guess ASGI object
    local appmod="main:app"
    [[ -f "$dir/app.py" ]] && grep -q 'FastAPI' "$dir/app.py" && appmod="app:app"
    (cd "$dir" && nohup uvicorn "$appmod" --host 127.0.0.1 --port "$port" > "$log" 2>&1 & echo $! > ".smoke.pid") || true
  else
    # Flask quick dev server (okay for smoke)
    local entry="main.py"
    [[ -f "$dir/app.py" ]] && entry="app.py"
    (cd "$dir" && FLASK_APP="$entry" nohup python "$entry" > "$log" 2>&1 & echo $! > ".smoke.pid") || true
  fi

  sleep 1
  # hit /healthz then /
  for path in /healthz /; do
    if curl -fsS "http://127.0.0.1:${port}${path}" >/dev/null 2>&1; then
      echo "    [✓] ${path} OK"
      break
    fi
  done

  # let it breathe a moment, then kill
  sleep "$SMOKE_SECS"
  if [[ -f "$dir/.smoke.pid" ]]; then
    kill "$(cat "$dir/.smoke.pid")" >/dev/null 2>&1 || true
    rm -f "$dir/.smoke.pid"
  fi

  echo "    [i] recent log tail:"
  tail -n 10 "$log" || true
}

echo "===================================================================================================="
echo "SERVICE PREP & SMOKE"
for svc in "${SERVICES[@]}"; do
  name="$(basename "$svc")"
  kind="$(classify_service "$svc")"
  printf "[*] %s  (kind=%s)\n" "$name" "$kind"

  case "$kind" in
    fastapi) write_fastapi_files "$svc" ;;
    flask)   write_flask_files "$svc" ;;
    unknown)
      echo "    [!] cannot detect framework; check imports in $svc/main.py or app.py"
      continue
      ;;
    none)
      echo "    [!] no main.py/app.py found in $svc"
      continue
      ;;
  esac

  # quick compile check
  if ! python -m py_compile $(find "$svc" -maxdepth 1 -name "*.py" -print) 2>/dev/null; then
    echo "    [!] py-compile FAILED — open the log for details"; continue
  else
    echo "    [✓] py-compile OK"
  fi

  smoke_one "$svc" "$kind"
done

deactivate || true

# ---------- 6) Commit & push (optional) ----------
if [[ "$PUSH" == "1" ]]; then
  git add -A
  git commit -m "chore: auto-fix services (reqs, Dockerfiles, ignores, submodule cleanup, smoke wiring)"
  git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1 || \
    { echo "[i] no upstream set; skipping push"; exit 0; }
  git push
  echo "[✓] pushed"
fi

echo "===================================================================================================="
echo "[✓] AUTO-FIX complete. Logs in .smoke/logs/"
