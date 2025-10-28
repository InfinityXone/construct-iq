#!/usr/bin/env bash
# ciq_merge_final_heal.sh
# One-button: analyze → auto-fix (optional) → results → local smoke test → optional push.
# Safe defaults. Use flags to act: --fix --purge-staging --set-workflows-manual --push

set -Eeuo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

# ---------- flags ----------
FIX=0
PURGE_STAGING=0
SET_WF_MANUAL=0
PUSH=0
for a in "$@"; do
  case "$a" in
    --fix) FIX=1 ;;
    --purge-staging) PURGE_STAGING=1 ;;
    --set-workflows-manual) SET_WF_MANUAL=1 ;;
    --push) PUSH=1 ;;
    --help|-h) echo "Usage: $0 [--fix] [--purge-staging] [--set-workflows-manual] [--push]"; exit 0 ;;
    *) echo "[warn] unknown flag: $a" ;;
  esac
done

TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT="ops/swarm/merge_supercheck_${TS}.txt"
mkdir -p ops/swarm /tmp/ciq-smoke .smoke

say(){ echo "$*" | tee -a "$REPORT"; }
hr(){ printf '%*s\n' 100 | tr ' ' '=' | tee -a "$REPORT"; }

hr
say "CONSTRUCT-IQ ⟂ SWARM — SUPER CHECK — ${TS}"
hr
say "[i] repo: $ROOT"
say "[i] branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
say "[i] flags: FIX=$FIX PURGE_STAGING=$PURGE_STAGING SET_WF_MANUAL=$SET_WF_MANUAL PUSH=$PUSH"

# ---------- basic repo sanity ----------
git status --porcelain=v1 | sed 's/^/  /' | tee -a "$REPORT" >/dev/null || true

# ---------- structure checks ----------
NEEDED_DIRS=(
  services
  services/memory-gateway
  services/orchestrator
  services/agents
  apps/swarm-dashboard
  ops/swarm
  infra/swarm
  docs/swarm
  .github/workflows
)
say ""
hr
say "DIRECTORY & NAMING CHECKS"
for d in "${NEEDED_DIRS[@]}"; do
  if [[ -d "$d" ]]; then
    say "[✓] $d"
  else
    say "[!] missing: $d"
    (( FIX )) && mkdir -p "$d"
  fi
done

# ---------- hygiene ----------
say ""
hr
say "HYGIENE (logs, staging, gitlinks)"
# memory-gateway logs should not be tracked
LGLOB="services/memory-gateway/*LOG.txt"
FOUND_LOGS=$(git ls-files -z $LGLOB 2>/dev/null | tr -d '\000' || true)
if [[ -n "${FOUND_LOGS:-}" ]]; then
  say "[!] tracked logs:"
  printf "%s\n" $FOUND_LOGS | sed 's/^/    - /' | tee -a "$REPORT"
  if (( FIX )); then
    git rm --cached $LGLOB || true
    grep -q 'services/memory-gateway/*LOG.txt' .gitignore 2>/dev/null || \
      printf "\n# memory-gateway runtime logs\nservices/memory-gateway/*LOG.txt\n" >> .gitignore
    git add .gitignore
    say "[✓] untracked logs + updated .gitignore"
  fi
else
  say "[✓] no tracked memory-gateway log files"
fi

# purge swarm-staging leftovers
if [[ -d "swarm-staging" ]]; then
  say "[!] leftover swarm-staging/ detected"
  (( PURGE_STAGING || FIX )) && { git rm -r --cached swarm-staging 2>/dev/null || true; rm -rf swarm-staging; say "[✓] purged swarm-staging/"; }
else
  say "[✓] no swarm-staging/"
fi

# normalize accidental gitlink (_from_github)
MODE=$(git ls-files -s _from_github 2>/dev/null | awk '{print $1}' || true)
if [[ "$MODE" == "160000" ]]; then
  say "[!] _from_github recorded as submodule/gitlink"
  if (( FIX )); then
    git rm --cached _from_github || true
    say "[✓] removed gitlink; directory will be normal files next commit"
  fi
else
  [[ -d _from_github ]] && say "[i] _from_github present as normal dir (ok)"
fi

# ---------- service readiness ----------
say ""
hr
say "SERVICE READINESS (main.py + Dockerfile + py-compile)"
mapfile -t SRVS < <(find services -mindepth 1 -maxdepth 2 -type f -name main.py -printf '%h\n' | sort -u)

ensure_files() {
  local dir="$1"
  local created=0

  # requirements.txt
  if [[ ! -f "$dir/requirements.txt" ]]; then
    if (( FIX )); then
      cat > "$dir/requirements.txt" <<'REQ'
fastapi
uvicorn[standard]
REQ
      created=1
    else
      say "    [~] missing requirements.txt"
    fi
  fi

  # Dockerfile
  if [[ ! -f "$dir/Dockerfile" ]]; then
    if (( FIX )); then
      cat > "$dir/Dockerfile" <<'DOCK'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
# Try common app names; uvicorn will fail fast if not present.
EXPOSE 8080
CMD ["bash","-lc","python - <<'PY'\ntry:\n import main as m\n import uvicorn\n app = getattr(m,'app',None)\n if app is not None:\n  uvicorn.run('main:app',host='0.0.0.0',port=8080)\n else:\n  import os; os.execvp('python',['python','main.py'])\nexcept Exception as e:\n import os; os.execvp('python',['python','main.py'])\nPY"]
DOCK
      created=1
    else
      say "    [~] missing Dockerfile"
    fi
  fi

  # py-compile sanity
  python - <<'PY' "$dir" 2>/dev/null && ok=1 || ok=0
import sys, py_compile, pathlib
p = pathlib.Path(sys.argv[1])/"main.py"
py_compile.compile(str(p), doraise=True)
PY
  if (( ok == 1 )); then
    say "    [✓] py-compile OK"
  else
    say "    [!] py-compile FAILED"
  fi

  return $created
}

for d in "${SRVS[@]}"; do
  say "[*] ${d#services/}"
  ensure_files "$d" || true
done
[[ ${#SRVS[@]} -eq 0 ]] && say "[i] no services/main.py found under services/*"

# ---------- workflows coercion (optional) ----------
say ""
hr
say "CI WORKFLOWS"
mapfile -t WF < <(ls .github/workflows/*.yml 2>/dev/null || true)
if ((${#WF[@]})); then
  for f in "${WF[@]}"; do
    if (( SET_WF_MANUAL )); then
      # back up once
      [[ -f "$f.bak" ]] || cp "$f" "$f.bak"
      if grep -qE '^on:' "$f"; then
        # replace the first 'on:' block with workflow_dispatch (lo-fi but safe)
        awk 'BEGIN{printed=0}
             /^on:/ && printed==0{print "on: [workflow_dispatch]"; skip=1; printed=1; next}
             skip && NF==0{skip=0; next}
             !skip{print}' "$f.bak" > "$f"
      else
        printf "on: [workflow_dispatch]\n%s" "$(cat "$f")" > "$f"
      fi
      say "  [~] coerced manual: $(basename "$f")"
    else
      say "  [i] $(basename "$f")"
    fi
  done
else
  say "[i] no workflows found"
fi

# ---------- docs stubs ----------
say ""
hr
say "DOCS"
for d in ops/swarm infra/swarm docs/swarm; do
  if [[ ! -f "$d/README.md" ]]; then
    if (( FIX )); then
      cat > "$d/README.md" <<EOF
# $(basename "$d")
This directory was migrated from infinity-x-one-swarm into Construct-IQ.
See MIGRATION_SWARM_MAP.md for original paths.
EOF
      say "  [~] created $d/README.md"
    else
      say "  [~] missing $d/README.md"
    fi
  else
    say "  [✓] $d/README.md present"
  fi
done

# ---------- commit & push ----------
if (( FIX )); then
  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "chore: supercheck autofixes (logs, Dockerfiles, docs, workflows${SET_WF_MANUAL:+ -> manual})" || true
    say "[✓] committed autofixes"
  else
    say "[i] nothing to commit"
  fi
fi
if (( PUSH )); then
  say "[i] pushing branch to origin…"
  git push -u origin "$(git rev-parse --abbrev-ref HEAD)" || true
fi

# ---------- local smoke (inline) ----------
say ""
hr
say "LOCAL SMOKE TEST"
# helpers
pick_port() { python3 - <<'PY'
import socket
s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()
PY
}
is_fastapi() {
  python3 - "$1" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])/"main.py"
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
  hr; echo "Report: $REPORT"; exit 0
fi

if ((${#SRVS[@]}==0)); then
  say "[i] no services to boot — skipping smoke test"
  hr; echo "Report: $REPORT"; exit 0
fi

for dir in "${SRVS[@]}"; do
  name="${dir#services/}"
  vdir=".smoke/.venv-$(echo -n "$dir" | sha1sum | awk '{print $1}')"
  log="/tmp/ciq-smoke/${name//\//_}_$(date +%s).log"
  mkdir -p /tmp/ciq-smoke

  say ""
  say "[*] ${name}"

  # venv + deps
  python3 -m venv "$vdir" >/dev/null 2>&1 || true
  # shellcheck disable=SC1091
  source "$vdir/bin/activate"
  python3 -m pip -q install --upgrade pip >/dev/null 2>&1 || true
  if [[ -f "$dir/requirements.txt" ]]; then
    python3 -m pip -q install -r "$dir/requirements.txt" >/dev/null 2>&1 || true
  else
    python3 -m pip -q install fastapi "uvicorn[standard]" >/dev/null 2>&1 || true
  fi

  kind="$(is_fastapi "$dir")"
  port="$(pick_port)"
  url="http://127.0.0.1:${port}"

  pushd "$dir" >/dev/null
  if [[ "$kind" == "yes" ]]; then
    setsid bash -c "uvicorn main:app --host 127.0.0.1 --port ${port} >'${log}' 2>&1" &
  else
    setsid bash -c "python3 main.py >'${log}' 2>&1" &
  fi
  pid=$!
  popd >/dev/null

  ok=0
  for _ in {1..20}; do
    sleep 0.5
    if curl -fsS "$url/health" >/dev/null 2>&1 || curl -fsS "$url/" >/dev/null 2>&1; then ok=1; break; fi
    kill -0 "$pid" >/dev/null 2>&1 || break
  done

  if (( ok )); then
    say "    -> PASS: ${url}"
  else
    say "    -> FAIL: ${url} — showing recent logs:"
    tail -n 50 "$log" 2>/dev/null | sed 's/^/         /' | tee -a "$REPORT" || true
  fi

  kill "$pid" >/dev/null 2>&1 || true
  sleep 0.3
  kill -9 "$pid" >/dev/null 2>&1 || true
  deactivate || true
done

say ""
hr
say "Report saved: $REPORT"
