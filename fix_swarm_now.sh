#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$HOME/construct-iq}"
DO_PUSH=0
[[ "${1:-}" == "--push" ]] && DO_PUSH=1

cd "$ROOT" 2>/dev/null || { echo "[!] run inside your construct-iq clone"; exit 1; }

echo "===================================================================================================="
echo "CONSTRUCT-IQ ⟂ SWARM — POST-MERGE HEAL — $(date -u +%Y%m%dT%H%M%SZ)"
echo "===================================================================================================="
echo "[i] repo: $ROOT"
git rev-parse --is-inside-work-tree >/dev/null || { echo "[!] not a git repo"; exit 1; }
BRANCH="$(git rev-parse --abbrev-ref HEAD || true)"
echo "[i] branch: $BRANCH"

# ────────────────────────────────────────────────────────────────────────────────
# 1) Ensure .gitignore shields local smoke env + logs (and stop tracking if any)
# ────────────────────────────────────────────────────────────────────────────────
ensure_ignore() {
  local pat="$1"
  grep -qxF "$pat" .gitignore || echo "$pat" >> .gitignore
}
ensure_ignore ""
ensure_ignore "# local smoke env + runtime logs"
ensure_ignore ".smoke/"
ensure_ignore ".smoke.pid"
ensure_ignore "services/*/*LOG.txt"

# drop anything already tracked under those paths
git rm -r --cached .smoke .smoke.pid 2>/dev/null || true

# ────────────────────────────────────────────────────────────────────────────────
# 2) Kill accidental submodules/gitlinks (you had one for _from_github before)
# ────────────────────────────────────────────────────────────────────────────────
if [[ -f .gitmodules ]]; then
  echo "[!] .gitmodules present — nuking accidental submodules"
  git submodule deinit -f --all || true
  git rm -f $(git config -f .gitmodules --name-only --get-regexp path | awk '{print $2}') || true
  rm -f .gitmodules || true
fi
if git ls-files --stage | awk '{print $2, $4}' | grep -qE '160000 .* _from_github$'; then
  echo "[!] removing gitlink entry for _from_github"
  git rm --cached _from_github || true
  rm -rf _from_github/.git || true
fi

# ────────────────────────────────────────────────────────────────────────────────
# 3) Patch your auto-fix smoke runner to use ABSOLUTE LOG PATHS
#    (your logs failed because we launched from inside each service)
# ────────────────────────────────────────────────────────────────────────────────
if [[ -f fix_swarm_now.sh ]]; then
  # idempotent patch: ensure LOGDIR="$ROOT/.smoke/logs" and mkdir -p before use
  # also ensure any '> $LOGDIR/…' becomes "> \"$LOGDIR/…\""
  awk -v root="$ROOT" '
    BEGIN{patched=0}
    /mkdir -p \.smoke\/logs/ {patched=1}
    {print}
    END{
      if(!patched){
        print "LOGDIR=\""$ENVIRON["ROOT"]"/.smoke/logs\""
        print "mkdir -p \"$LOGDIR\""
      }
    }
  ' fix_swarm_now.sh > .tmp.fix && mv .tmp.fix fix_swarm_now.sh

  # Replace relative .smoke/logs with $LOGDIR
  sed -i 's|\$LOGDIR/|$LOGDIR/|g' fix_swarm_now.sh

  chmod +x fix_swarm_now.sh
  echo "[✓] patched fix_swarm_now.sh to use absolute log dir"
fi

# ────────────────────────────────────────────────────────────────────────────────
# 4) Quick double-check: service req/Dockerfiles exist; add minimal if missing
# ────────────────────────────────────────────────────────────────────────────────
mk_fastapi() {
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
mk_flask() {
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

for S in services/*; do
  [[ -d "$S" ]] || continue
  if [[ -f "$S/main.py" ]] || [[ -f "$S/app.py" ]]; then
    if grep -q 'FastAPI' "$S"/*py 2>/dev/null; then mk_fastapi "$S"
    elif grep -qE 'from flask|import flask' "$S"/*py 2>/dev/null; then mk_flask "$S"
    fi
  fi
done

# ────────────────────────────────────────────────────────────────────────────────
# 5) Run local smoke (absolute logs) without committing anything yet
# ────────────────────────────────────────────────────────────────────────────────
LOGDIR="$ROOT/.smoke/logs"; mkdir -p "$LOGDIR"
python3 -m venv "$ROOT/.smoke/venv"
source "$ROOT/.smoke/venv/bin/activate"
pip install --upgrade pip >/dev/null

smoke_one () {
  local dir="$1" kind="$2" name; name="$(basename "$dir")"
  local port
  port="$(python - <<'PY'
import socket,random
s=socket.socket()
while True:
  p=random.randint(20000,59999)
  try:
    s.bind(("127.0.0.1",p)); s.close(); print(p); break
  except OSError:
    pass
PY
)"
  local log="$LOGDIR/${name}.log"
  rm -f "$log"

  echo "[*] $name (kind=$kind)"
  pip install -r "$dir/requirements.txt" >/dev/null 2>&1 || true
  if [[ "$kind" == "fastapi" ]]; then
    local appmod="main:app"
    [[ -f "$dir/app.py" ]] && grep -q 'FastAPI' "$dir/app.py" && appmod="app:app"
    (cd "$dir" && nohup uvicorn "$appmod" --host 127.0.0.1 --port "$port" > "$log" 2>&1 & echo $! > "$ROOT/.smoke/${name}.pid")
  else
    local entry="main.py"; [[ -f "$dir/app.py" ]] && entry="app.py"
    (cd "$dir" && FLASK_APP="$entry" nohup python "$entry" > "$log" 2>&1 & echo $! > "$ROOT/.smoke/${name}.pid")
  fi

  # probe /healthz or /
  sleep 1
  if curl -fsS "http://127.0.0.1:${port}/healthz" >/dev/null 2>&1 || \
     curl -fsS "http://127.0.0.1:${port}/" >/dev/null 2>&1 ; then
     echo "    [✓] responded on :$port"
  else
     echo "    [!] no response on :$port (check $log)"
  fi

  sleep 6
  kill "$(cat "$ROOT/.smoke/${name}.pid")" >/dev/null 2>&1 || true
  rm -f "$ROOT/.smoke/${name}.pid"
  echo "    [i] tail:"
  tail -n 12 "$log" || true
}

# classify and smoke only the two services we care about now
declare -A KIND
for d in services/memory-gateway services/orchestrator; do
  [[ -d "$d" ]] || continue
  if grep -q 'FastAPI' "$d"/*py 2>/dev/null; then KIND["$d"]="fastapi"
  elif grep -qE 'from flask|import flask' "$d"/*py 2>/dev/null; then KIND["$d"]="flask"
  else KIND["$d"]="unknown"; fi
done

for d in "${!KIND[@]}"; do
  [[ "${KIND[$d]}" == "unknown" ]] && { echo "[!] $d: unknown framework"; continue; }
  smoke_one "$d" "${KIND[$d]}"
done
deactivate || true

# ────────────────────────────────────────────────────────────────────────────────
# 6) Commit & push (optional) — after we’ve removed tracked .smoke files
# ────────────────────────────────────────────────────────────────────────────────
# if any .smoke content is still staged, unstage it
git reset HEAD .smoke .smoke.pid >/dev/null 2>&1 || true

git add -A
if ! git diff --cached --quiet; then
  git commit -m "chore: post-merge heal (ignore .smoke, fix logs path, req/Dockerfiles, submodule cleanup)"
  echo "[✓] committed autofixes"
else
  echo "[i] nothing to commit"
fi

if [[ "$DO_PUSH" -eq 1 ]]; then
  # convert origin to HTTPS if needed (your SSH failed earlier)
  if git remote get-url origin | grep -q '^git@github.com:'; then
    git remote set-url origin "https://github.com/$(git remote get-url origin | sed -E 's#^git@github.com:(.+)$#\1#')"
    echo "[i] switched origin to HTTPS"
  fi
  # final safety: refuse if any >10MiB file is staged (should be none now)
  if find . -type f -size +10M ! -path "./.git/*" | grep -q .; then
    echo "[!] large files >10MiB detected in working tree — push aborted"
    exit 2
  fi
  git push || { echo "[!] push failed"; exit 3; }
  echo "[✓] push OK"
fi

echo "===================================================================================================="
echo "[✓] HEAL COMPLETE — logs in $LOGDIR"
LOGDIR="echo "[✓] HEAL COMPLETE — logs in $LOGDIR"/.smoke/logs"
mkdir -p "$LOGDIR"
