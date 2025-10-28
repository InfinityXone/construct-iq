#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$HOME/construct-iq}"
DO_PUSH=0
[[ "${1:-}" == "--push" ]] && DO_PUSH=1

cd "$ROOT" || { echo "[!] not in repo"; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null || { echo "[!] not a git repo"; exit 1; }
BRANCH="$(git rev-parse --abbrev-ref HEAD || true)"

echo "===================================================================================================="
echo "CONSTRUCT-IQ ⟂ SWARM — QUICK HEAL + SMOKE — $(date -u +%Y%m%dT%H%M%SZ)"
echo "===================================================================================================="
echo "[i] repo: $ROOT"
echo "[i] branch: $BRANCH"

# ────────────────────────────────────────────────────────────────────────────────
# Hygiene: ignore local smoke env/logs, drop any accidental gitlinks/submodules
# ────────────────────────────────────────────────────────────────────────────────
append_ignore() { grep -qxF "$1" .gitignore || echo "$1" >> .gitignore; }
append_ignore ""
append_ignore "# local smoke env + runtime logs"
append_ignore ".smoke/"
append_ignore ".smoke.pid"
append_ignore "services/*/*LOG.txt"

# stop tracking if ever added
git rm -r --cached .smoke .smoke.pid 2>/dev/null || true

# kill accidental submodules/gitlinks
if [[ -f .gitmodules ]]; then
  echo "[!] .gitmodules present — removing any submodules"
  git submodule deinit -f --all || true
  # remove each path listed in .gitmodules
  while read -r _ path; do git rm -f "$path" || true; done < <(git config -f .gitmodules --name-only --get-regexp path | xargs -I{} sh -lc 'echo path $(git config -f .gitmodules {} )')
  rm -f .gitmodules || true
fi
# kill a gitlink named _from_github if present
if git ls-files --stage | awk '{print $2, $4}' | grep -qE '160000 .* _from_github$'; then
  echo "[!] removing gitlink entry for _from_github"
  git rm --cached _from_github || true
  rm -rf _from_github/.git || true
fi

# ────────────────────────────────────────────────────────────────────────────────
# Service baselines: ensure minimal reqs + Dockerfiles (non-destructive)
# ────────────────────────────────────────────────────────────────────────────────
mk_fastapi_basics() {
  local d="$1"
  [[ -f "$d/requirements.txt" ]] || cat > "$d/requirements.txt" <<'REQ'
fastapi>=0.103
uvicorn[standard]>=0.23
python-dotenv>=1.0
REQ
  [[ -f "$d/Dockerfile" ]] || cat > "$d/Dockerfile" <<'DOCKER'
FROM python:3.11-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8080
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8080"]
DOCKER
}
mk_flask_basics() {
  local d="$1"
  [[ -f "$d/requirements.txt" ]] || cat > "$d/requirements.txt" <<'REQ'
flask>=3.0
gunicorn>=21.2
python-dotenv>=1.0
REQ
  [[ -f "$d/Dockerfile" ]] || cat > "$d/Dockerfile" <<'DOCKER'
FROM python:3.11-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8080
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
ENV GUNICORN_APP=main:app
CMD ["bash","-lc","exec gunicorn --bind 0.0.0.0:${PORT} ${GUNICORN_APP}"]
DOCKER
}

# only touch the two critical services
[[ -d services/memory-gateway ]] && mk_fastapi_basics services/memory-gateway || true
[[ -d services/orchestrator   ]] && mk_flask_basics   services/orchestrator   || true

# ────────────────────────────────────────────────────────────────────────────────
# Local smoke: isolated venv, absolute logs, resilient import/install checks
# ────────────────────────────────────────────────────────────────────────────────
LOGDIR="$ROOT/.smoke/logs"; mkdir -p "$LOGDIR"
VENV="$ROOT/.smoke/venv"
python3 -m venv "$VENV" 2>/dev/null || true
source "$VENV/bin/activate"
python -m pip install -q --upgrade pip wheel setuptools

need_port() {
python - <<'PY'
import random,socket
s=socket.socket()
while True:
  p=random.randint(20000,59999)
  try:
    s.bind(("127.0.0.1",p)); s.close(); print(p); break
  except OSError:
    pass
PY
}

http_ok_or_404 () {  # $1 url
  code="$(curl -s -o /dev/null -w "%{http_code}" "$1" || echo 000)"
  # treat 2xx/3xx/404 as "server responding"
  [[ "$code" =~ ^2|3|404$ ]]
}

smoke_fastapi() { # dir
  local d="$1"; local name="$(basename "$d")"; local log="$LOGDIR/${name}.log"
  local port; port="$(need_port)"
  # deps (retry once)
  python - <<'PY' 2>/dev/null || pip install -q fastapi "uvicorn[standard]"
import fastapi,uvicorn  # noqa
PY
  # pick module: main:app or app:app
  local appmod="main:app"; [[ -f "$d/app.py" ]] && grep -q 'FastAPI' "$d/app.py" && appmod="app:app"
  : > "$log"
  ( cd "$d" && nohup uvicorn "$appmod" --host 127.0.0.1 --port "$port" >>"$log" 2>&1 & echo $! > "$ROOT/.smoke/${name}.pid" )
  sleep 1
  if http_ok_or_404 "http://127.0.0.1:${port}/healthz" || http_ok_or_404 "http://127.0.0.1:${port}/"; then
    echo "    [✓] $name responded on :$port"
  else
    echo "    [!] $name no response on :$port (see $log)"
  fi
  sleep 4
  kill "$(cat "$ROOT/.smoke/${name}.pid")" >/dev/null 2>&1 || true
  rm -f "$ROOT/.smoke/${name}.pid"
  echo "    [i] tail:"; tail -n 14 "$log" || true
}

smoke_flask() { # dir
  local d="$1"; local name="$(basename "$d")"; local log="$LOGDIR/${name}.log"
  local port; port="$(need_port)"
  # deps (retry once)
  python - <<'PY' 2>/dev/null || pip install -q flask gunicorn
import flask,gunicorn  # noqa
PY
  local target="main:app"; [[ -f "$d/app.py" ]] && target="app:app"
  : > "$log"
  ( cd "$d" && nohup gunicorn --bind 127.0.0.1:"$port" "$target" >>"$log" 2>&1 & echo $! > "$ROOT/.smoke/${name}.pid" )
  sleep 1
  if http_ok_or_404 "http://127.0.0.1:${port}/healthz" || http_ok_or_404 "http://127.0.0.1:${port}/"; then
    echo "    [✓] $name responded on :$port"
  else
    echo "    [!] $name no response on :$port (see $log)"
  fi
  sleep 4
  kill "$(cat "$ROOT/.smoke/${name}.pid")" >/dev/null 2>&1 || true
  rm -f "$ROOT/.smoke/${name}.pid"
  echo "    [i] tail:"; tail -n 14 "$log" || true
}

echo "===================================================================================================="
echo "LOCAL SMOKE"
[[ -d services/memory-gateway ]] && { echo "[*] memory-gateway (FastAPI)"; smoke_fastapi services/memory-gateway; } || echo "[ ] memory-gateway missing"
[[ -d services/orchestrator   ]] && { echo "[*] orchestrator (Flask)";   smoke_flask   services/orchestrator;   } || echo "[ ] orchestrator missing"

deactivate || true

# ────────────────────────────────────────────────────────────────────────────────
# Commit + push (optional)
# ────────────────────────────────────────────────────────────────────────────────
git add -A
if ! git diff --cached --quiet; then
  git commit -m "chore: post-merge quick heal (ignore .smoke, ensure reqs/dockerfiles, robust smoke)"
  echo "[✓] committed autofixes"
else
  echo "[i] nothing to commit"
fi

if [[ "$DO_PUSH" -eq 1 ]]; then
  # prefer HTTPS to dodge SSH hiccups
  if git remote get-url origin | grep -q '^git@github.com:'; then
    git remote set-url origin "https://github.com/$(git remote get-url origin | sed -E 's#^git@github.com:(.+)$#\1#')"
    echo "[i] switched origin to HTTPS"
  fi
  # safety: block oversized binaries
  if find . -type f -size +10M ! -path "./.git/*" | grep -q .; then
    echo "[!] large files >10MiB detected — push aborted"; exit 2
  fi
  git push && echo "[✓] push OK"
fi

echo "===================================================================================================="
echo "[✓] HEAL + SMOKE COMPLETE — logs in $LOGDIR"
