#!/usr/bin/env bash
# ciq_merge_diagnose_and_fix_v2.sh
# Post-merge diagnostics + optional auto-fix + smoke test for Construct-IQ ⟂ Swarm.
# Fixes previous 'syntax error near `2'' by using nullglob (no redirections inside for-lists).

set -Eeuo pipefail

# ---------------- Config / Flags ----------------
FIX=false                 # --fix to apply non-destructive fixes
PURGE_STAGING=false       # --purge-staging to delete leftover swarm-staging/
WORKFLOWS_MANUAL=false    # --set-workflows-manual to force workflow_dispatch
PUSH_CHANGES=false        # --push to push any committed fixes
REMOTE="${REMOTE:-origin}"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix)                  FIX=true;;
    --purge-staging)        PURGE_STAGING=true;;
    --set-workflows-manual) WORKFLOWS_MANUAL=true;;
    --push)                 PUSH_CHANGES=true;;
    --remote=*)             REMOTE="${1#*=}";;
    *) echo "[warn] Unknown flag: $1";;
  esac; shift
done

# ---------------- Helpers ----------------------
die(){ echo "ERROR: $*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }
line(){ printf '%*s\n' "${1:-80}" | tr ' ' '='; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Run inside your git repo."

TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_DIR="ops/swarm"
REPORT="$REPORT_DIR/merge_diagnostics_${TS}.txt"
mkdir -p "$REPORT_DIR"

note(){ echo "$*" | tee -a "$REPORT"; }
headr(){ line 100 | tee -a "$REPORT"; echo "$*" | tee -a "$REPORT"; line 100 | tee -a "$REPORT"; }

changed=false
safe_commit(){ if $changed; then git add -A && git commit -m "$1" && changed=false; fi }

# ---------------- Expected Layout --------------
declare -a MUST_DIRS=(
  "services"
  "services/memory-gateway"
  "services/orchestrator"
  "services/agents"
  "apps/swarm-dashboard"
  "ops/swarm"
  "infra/swarm"
  "docs/swarm"
  ".github/workflows"
)

# ---------------- Report: header ---------------
headr "CONSTRUCT-IQ ⟂ SWARM MERGE DIAGNOSTICS — $TS (branch: $BRANCH)"
note "[i] Repo root: $(git rev-parse --show-toplevel)"
note "[i] Remote: $(git remote get-url "$REMOTE" 2>/dev/null || echo 'n/a')"
note "[i] Git status (short):"
git status -s | sed 's/^/  /' | tee -a "$REPORT"

# ---------------- Directory checks -------------
headr "DIRECTORY & NAMING CHECKS"
missing=0
for d in "${MUST_DIRS[@]}"; do
  if [[ -d "$d" ]]; then
    note "[✓] $d"
  else
    note "[✗] $d (missing)"
    ((missing++))
    if $FIX; then
      mkdir -p "$d"; note "    -> created"; changed=true
    fi
  fi
done

# Detect agent dirs
if [[ -d services/agents ]]; then
  mapfile -t AGENTS < <(find services/agents -maxdepth 2 -mindepth 1 -type d -printf "%P\n" | sort)
else
  AGENTS=()
fi
note ""
note "[i] Detected agents (services/agents/*):"
if [[ ${#AGENTS[@]} -gt 0 ]]; then
  for a in "${AGENTS[@]}"; do note "  - $a"; done
else
  note "  (none found)"
fi

# ---------------- Hygiene ----------------------
headr "HYGIENE CHECKS (staging, big files, temp/log files)"

# Staging
if [[ -d swarm-staging ]]; then
  note "[! ] leftover: swarm-staging/ exists"
  if $PURGE_STAGING; then
    git rm -r swarm-staging >/dev/null 2>&1 || true
    rm -rf swarm-staging
    note "    -> purged swarm-staging/"; changed=true
  fi
else
  note "[✓] no swarm-staging/"
fi

# Large files (>=25MB)
note ""
note "[i] Large files ≥ 25MB in repo (may bloat CI):"
FOUND_LARGE=false
while IFS= read -r -d '' path; do
  size_mb=$(du -m "$path" 2>/dev/null | awk '{print $1}')
  if [[ -n "${size_mb:-}" && "$size_mb" -ge 25 ]]; then
    note "  - $path (${size_mb}MB)"; FOUND_LARGE=true
  fi
done < <(git ls-files -z)
$FOUND_LARGE || note "  (none ≥25MB)"

# Repo logs in memory-gateway (use nullglob; no redirection in list)
shopt -s nullglob
LOGS=(services/memory-gateway/*LOG.txt)
if (( ${#LOGS[@]} )); then
  for f in "${LOGS[@]}"; do note "[! ] repo log present: $f"; done
else
  note "[✓] no *.LOG.txt files tracked in services/memory-gateway"
fi
shopt -u nullglob

# ---------------- Service readiness -----------
headr "SERVICE READINESS (Dockerfile + main.py + py-compile)"

create_dockerfile(){
  local dir="$1"
  cat > "$dir/Dockerfile" <<'DOCKER'
FROM python:3.11-slim
WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt || true

COPY . /app

# If FastAPI detected in main.py, uvicorn; else run main.py
CMD bash -lc 'python - <<PY
import os, re
p="main.py"
if os.path.exists(p):
    t=open(p,"r",encoding="utf-8",errors="ignore").read()
    if re.search(r"FastAPI\\s*\\(", t):
        print("uvicorn main:app --host 0.0.0.0 --port 8080")
    else:
        print("python main.py")
else:
    print("python -c \\"print(\\'No main.py; customize CMD\\')\\"")
PY' | xargs -r sh -c
DOCKER
  note "    -> created Dockerfile"; changed=true
}

create_requirements(){
  local dir="$1"
  if [[ ! -f "$dir/requirements.txt" ]]; then
    cat > "$dir/requirements.txt" <<'REQ'
fastapi
uvicorn[standard]
REQ
    note "    -> created requirements.txt (fastapi/uvicorn baseline)"; changed=true
  fi
}

check_service(){
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  local has_main="no"; local has_docker="no"
  [[ -f "$dir/main.py" ]] && has_main="yes"
  [[ -f "$dir/Dockerfile" ]] && has_docker="yes"

  if [[ "$has_main" = "yes" && "$has_docker" = "no" ]]; then
    note "[~] $dir : main.py found, Dockerfile missing"
    $FIX && { create_dockerfile "$dir"; create_requirements "$dir"; }
  else
    note "[✓] $dir : main.py=$has_main Dockerfile=$has_docker"
  fi

  # Python bytecode check (no import side-effects executed)
  if [[ "$has_main" = "yes" ]]; then
    if have python3; then
      if python3 -m py_compile "$dir/main.py" 2>>"$REPORT"; then
        note "    -> py_compile OK"
      else
        note "    -> [!] py_compile FAILED (see report)"
      fi
    else
      note "    -> python3 not available; skipped py_compile"
    fi
  fi
}

# Core services
check_service "services/memory-gateway"
check_service "services/orchestrator"

# Agent services
for agent_path in "${AGENTS[@]}"; do
  [[ -d "services/agents/$agent_path" ]] && check_service "services/agents/$agent_path"
done

# ---------------- Workflows -------------------
headr "CI WORKFLOWS (.github/workflows)"
WF_DIR=".github/workflows"
if [[ -d "$WF_DIR" ]]; then
  shopt -s nullglob
  WF_FILES=( "$WF_DIR"/*.yml "$WF_DIR"/*.yaml )
  if (( ${#WF_FILES[@]} == 0 )); then
    note "(no workflows found)"
  else
    for wf in "${WF_FILES[@]}"; do
      base="$(basename "$wf")"
      if [[ "$base" != swarm-* && "$base" != ciq-* ]]; then
        note "[! ] workflow not namespaced: $base"
      else
        note "[✓] $base"
      fi
      if $WORKFLOWS_MANUAL; then
        # Coerce triggers to workflow_dispatch
        # Replace entire on: block conservatively
        if grep -qE '^on:' "$wf"; then
          awk '
            BEGIN{in_on=0}
            /^on:[[:space:]]*$/ {print "on:\n  workflow_dispatch: {}"; in_on=1; next}
            in_on && NF==0 {in_on=0; next}
            in_on {next}
            {print}
          ' "$wf" > "$wf.tmp" && mv "$wf.tmp" "$wf"
          note "    -> set to workflow_dispatch"; changed=true
        fi
      fi
    done
  fi
  shopt -u nullglob
else
  note "(no .github/workflows dir)"
fi

# ---------------- Documentation --------------
headr "DOCUMENTATION CHECKS"
for d in "services/memory-gateway" "services/orchestrator" "apps/swarm-dashboard" "ops/swarm" "infra/swarm" "docs/swarm"; do
  if [[ -d "$d" ]]; then
    if [[ ! -f "$d/README.md" ]]; then
      note "[~] $d : README.md missing"
      if $FIX; then
        cat > "$d/README.md" <<EOF
# $(basename "$d")
Merged from infinity-x-one-swarm into Construct-IQ.

- Purpose: $(basename "$d") component
- Deploy: containerized (Cloud Run recommended)
- Health: expose /health (200 OK)
- Secrets: use GCP Secret Manager (avoid .env in repo)
EOF
        note "    -> created $d/README.md"; changed=true
      fi
    else
      note "[✓] $d : README.md present"
    fi
  fi
done

safe_commit "chore: post-merge autofixes (Dockerfiles, workflows, READMEs)"

# ---------------- Smoke Test (static) --------
headr "SMOKE TEST (STATIC INVENTORY)"
echo "[*] repo top-level:" | tee -a "$REPORT"
ls -la | sed 's/^/  /' | tee -a "$REPORT"

echo "" | tee -a "$REPORT"
echo "[*] services with entrypoints:" | tee -a "$REPORT"
find services -maxdepth 2 -mindepth 1 -type d | sort | while read -r d; do
  has_main="no"; has_docker="no"
  [[ -f "$d/main.py" ]] && has_main="yes"
  [[ -f "$d/Dockerfile" ]] && has_docker="yes"
  printf "  - %s : main.py=%s Dockerfile=%s\n" "$d" "$has_main" "$has_docker" | tee -a "$REPORT"
done

echo "" | tee -a "$REPORT"
echo "[*] workflow files:" | tee -a "$REPORT"
( shopt -s nullglob; for f in "$WF_DIR"/*; do echo "  $f"; done; ) | tee -a "$REPORT" || true

echo "" | tee -a "$REPORT"
echo "[*] Uncommitted changes after fixes:" | tee -a "$REPORT"
git status -s | sed 's/^/  /' | tee -a "$REPORT"

headr "RESULT"
if git diff --quiet && git diff --cached --quiet; then
  note "[✓] No pending changes."
else
  note "[! ] Pending changes exist (see 'git status')."
fi

# ---------------- Optional push --------------
if $PUSH_CHANGES; then
  note ""
  note "[i] Pushing branch '$BRANCH' to '$REMOTE'…"
  if ! git push -u "$REMOTE" "$BRANCH"; then
    note "[!] Push failed. If needed, switch origin to HTTPS:"
    note "    git remote set-url $REMOTE https://github.com/InfinityXone/construct-iq.git"
  fi
fi

echo ""
echo "=== Report saved to: $REPORT ==="
