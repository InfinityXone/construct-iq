#!/usr/bin/env bash
# ciq_merge_diagnose_and_fix.sh
# Full post-merge diagnostics for housing infinity-x-one-swarm inside construct-iq,
# with optional auto-fixes and a smoke test. Produces a concise report.

set -Eeuo pipefail

# -------- Config / Flags -------------------------------------------------------
FIX=false                 # --fix to apply non-destructive auto-fixes
PURGE_STAGING=false       # --purge-staging to delete leftover swarm-staging/
WORKFLOWS_MANUAL=false    # --set-workflows-manual to force workflow_dispatch
PUSH_CHANGES=false        # --push to push the commit
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
  esac
  shift
done

# -------- Helpers --------------------------------------------------------------
die(){ echo "ERROR: $*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }
line(){ printf '%*s\n' "${1:-70}" | tr ' ' '='; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Run inside your git repo (construct-iq)."

TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT="ops/swarm/merge_diagnostics_${TS}.txt"
mkdir -p ops/swarm

note(){ echo "$*" | tee -a "$REPORT"; }
headr(){ line 90 | tee -a "$REPORT"; echo "$*" | tee -a "$REPORT"; line 90 | tee -a "$REPORT"; }

changed=false
safe_commit(){ if $changed; then git add -A && git commit -m "$1" && changed=false; fi }

# -------- Expected Structure Map ----------------------------------------------
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

# services/agents children are dynamic; we’ll list after detection
declare -a EXPECTED_WORKFLOW_PREFIX=("swarm-")

# -------- Start Report ---------------------------------------------------------
headr "CONSTRUCT-IQ ⟂ SWARM MERGE DIAGNOSTICS — $TS (branch: $BRANCH)"

# Basic repo + status
note "[i] Repo root: $(git rev-parse --show-toplevel)"
note "[i] Remote: $(git remote get-url "$REMOTE" 2>/dev/null || echo 'n/a')"
note "[i] Git status (short):"
git status -s | sed 's/^/  /' | tee -a "$REPORT"

# -------- Directory Checks -----------------------------------------------------
headr "DIRECTORY & NAMING CHECKS"
missing=0
for d in "${MUST_DIRS[@]}"; do
  if [[ -d "$d" ]]; then
    note "[✓] $d"
  else
    note "[✗] $d (missing)"
    ((missing++))
    if $FIX; then
      mkdir -p "$d"
      note "    -> created"
      changed=true
    fi
  fi
done

# Detect agent folders
if [[ -d services/agents ]]; then
  mapfile -t AGENTS < <(find services/agents -maxdepth 2 -mindepth 1 -type d -printf "%P\n" | sort)
else
  AGENTS=()
fi
note ""
note "[i] Detected agents (services/agents/*):"
for a in "${AGENTS[@]}"; do note "  - $a"; done
[[ ${#AGENTS[@]} -eq 0 ]] && note "  (none found)"

# -------- File Hygiene / Collisions -------------------------------------------
headr "HYGIENE CHECKS (staging, big files, temp files)"
if [[ -d swarm-staging ]]; then
  note "[! ] leftover: swarm-staging/ exists"
  if $PURGE_STAGING; then
    git rm -r swarm-staging >/dev/null 2>&1 || true
    rm -rf swarm-staging
    note "    -> purged swarm-staging/"
    changed=true
  fi
else
  note "[✓] no swarm-staging/"
fi

# large blobs (>=25MB)
note ""
note "[i] Large files ≥ 25MB in repo (may bloat CI):"
FOUND_LARGE=false
while read -r path; do
  [[ -z "$path" ]] && continue
  size=$(du -m "$path" 2>/dev/null | awk '{print $1}')
  if [[ -n "$size" && "$size" -ge 25 ]]; then
    note "  - $path (${size}MB)"
    FOUND_LARGE=true
  fi
done < <(git ls-files | tr '\n' '\0' | xargs -0 -I{} bash -c 'printf "%s\n" "{}"')

$FOUND_LARGE || note "  (none ≥25MB)"

# temp/log leftovers inside services/memory-gateway
for f in services/memory-gateway/*LOG.txt 2>/dev/null; do
  if [[ -f "$f" ]]; then
    note "[! ] repo log present: $f"
  fi
done

# -------- Service Readiness (Dockerfile/main.py) ------------------------------
headr "SERVICE READINESS (Dockerfile + main.py)"
create_dockerfile(){
  local dir="$1"
  cat > "$dir/Dockerfile" <<'DOCKER'
FROM python:3.11-slim
WORKDIR /app

# Speed & reproduce
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt || true

COPY . /app

# Try uvicorn if FastAPI detected; else run main.py
# You can override CMD at deploy time.
CMD bash -lc 'python - <<PY
import importlib.util, sys, os, re
path="main.py"
if os.path.exists(path):
    txt=open(path,"r",encoding="utf-8",errors="ignore").read()
    if re.search(r"FastAPI\\s*\\(", txt):
        print("uvicorn main:app --host 0.0.0.0 --port 8080")
    else:
        print("python main.py")
else:
    print("python -c \\"print(\\'No main.py; customize CMD in Dockerfile\\')\\"")
PY' | xargs -r sh -c
DOCKER
  note "    -> created Dockerfile"
  changed=true
}

create_requirements(){
  local dir="$1"
  if [[ ! -f "$dir/requirements.txt" ]]; then
    cat > "$dir/requirements.txt" <<'REQ'
fastapi
uvicorn[standard]
REQ
    note "    -> created requirements.txt (fastapi/uvicorn baseline)"
    changed=true
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
}

# core services
check_service "services/memory-gateway"
check_service "services/orchestrator"

# agents as services
for agent_path in "${AGENTS[@]}"; do
  # Accept agent dirs like agents/visionary-agent or agents/agents/visionary-agent (already moved)
  if [[ -d "services/agents/$agent_path" ]]; then
    check_service "services/agents/$agent_path"
  fi
done

# -------- Workflows: ensure namespaced & manual triggers ----------------------
headr "CI WORKFLOWS (.github/workflows)"
WF_DIR=".github/workflows"
if [[ -d "$WF_DIR" ]]; then
  mapfile -t WF_FILES < <(ls "$WF_DIR"/*.yml "$WF_DIR"/*.yaml 2>/dev/null || true)
  if [[ ${#WF_FILES[@]} -eq 0 ]]; then
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
        # Force manual dispatch by replacing triggers with workflow_dispatch (very conservative)
        if grep -qE '^on:\s*$' "$wf"; then
          sed -i.bak 's/^on:\s*$/on:\n  workflow_dispatch: {}/' "$wf" && rm -f "$wf.bak"
          note "    -> set to workflow_dispatch"
          changed=true
        elif grep -qE '^on:\s*\n' "$wf"; then
          # If multiple triggers exist, replace the whole on: block with workflow_dispatch
          awk 'BEGIN{p=1} /^on:/{print "on:\n  workflow_dispatch: {}"; skip=1; next} skip && NF==0{skip=0; next} !skip{print}' "$wf" > "$wf.tmp" && mv "$wf.tmp" "$wf"
          note "    -> coerced to workflow_dispatch"
          changed=true
        fi
      fi
    done
  fi
else
  note "(no .github/workflows dir)"
fi

# -------- Documentation breadcrumbs ------------------------------------------
headr "DOCUMENTATION CHECKS"
doc_missing=0
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
- Secrets: use GCP Secret Manager (no .env in repo)
EOF
        note "    -> created $d/README.md"
        changed=true
      fi
    else
      note "[✓] $d : README.md present"
    fi
  fi
done

safe_commit "chore: post-merge autofixes (Dockerfiles, workflows, READMEs)"

# -------- Smoke Test (static) -------------------------------------------------
headr "SMOKE TEST (STATIC)"
echo "[*] repo top-level:" | tee -a "$REPORT"
ls -la | sed 's/^/  /' | tee -a "$REPORT"

echo "" | tee -a "$REPORT"
echo "[*] services with entrypoints:" | tee -a "$REPORT"
while read -r d; do
  [[ -z "$d" ]] && continue
  has_main="no"; has_docker="no"
  [[ -f "$d/main.py" ]] && has_main="yes"
  [[ -f "$d/Dockerfile" ]] && has_docker="yes"
  printf "  - %s : main.py=%s Dockerfile=%s\n" "$d" "$has_main" "$has_docker" | tee -a "$REPORT"
done < <(find services -maxdepth 2 -mindepth 1 -type d | sort)

echo "" | tee -a "$REPORT"
echo "[*] workflow files:" | tee -a "$REPORT"
ls "$WF_DIR"/* 2>/dev/null | sed 's/^/  /' | tee -a "$REPORT" || echo "  (none)" | tee -a "$REPORT"

echo "" | tee -a "$REPORT"
echo "[*] Uncommitted changes after fixes:" | tee -a "$REPORT"
git status -s | sed 's/^/  /' | tee -a "$REPORT"

headr "RESULT"
if git diff --quiet && git diff --cached --quiet; then
  note "[✓] No pending changes."
else
  note "[! ] Pending changes exist (see 'git status')."
fi

# -------- Optional push -------------------------------------------------------
if $PUSH_CHANGES; then
  note ""
  note "[i] Pushing branch '$BRANCH' to '$REMOTE'…"
  if ! git push -u "$REMOTE" "$BRANCH"; then
    note "[!] Push failed. You can switch origin to HTTPS:"
    note "    git remote set-url $REMOTE https://github.com/InfinityXone/construct-iq.git"
  fi
fi

echo ""
echo "=== Report saved to: $REPORT ==="
