#!/usr/bin/env bash
# merge_swarm_resilient.sh — fixes untracked-file pull error, then does a safe subtree import + move + push.
# Modes for handling local docs: DOCS_MODE=stash|commit|backup   (default: stash)

set -Eeuo pipefail

SWARM_REPO="${SWARM_REPO:-https://github.com/InfinityXone/infinity-x-one-swarm.git}"
SWARM_BRANCH="${SWARM_BRANCH:-main}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
STAGING_PREFIX="${STAGING_PREFIX:-swarm-staging}"
PUSH_REMOTE="${PUSH_REMOTE:-origin}"
DOCS_MODE="${DOCS_MODE:-stash}"   # stash | commit | backup
DOCS_DIR="${DOCS_DIR:-docs}"

have(){ command -v "$1" >/dev/null 2>&1; }
die(){ echo "ERROR: $*" >&2; exit 1; }
say(){ echo "[i] $*"; }

have git || die "git required."
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "run inside a git repo"

# --- Step 0: make a working branch now (so your fixes live on this PR branch)
git fetch --all --tags --prune >/dev/null 2>&1 || true
git checkout "$TARGET_BRANCH" || die "no $TARGET_BRANCH branch"
BRANCH="merge/swarm-$(date -u +%Y%m%dT%H%M%SZ)"
say "creating branch $BRANCH"
git checkout -b "$BRANCH"

# --- Step 1: fix 'untracked would be overwritten' before pulling
needs_fix=false
if ! git diff-index --quiet HEAD -- || ! git diff --quiet; then
  needs_fix=true
fi
# also detect untracked files under docs/
if [ -d "$DOCS_DIR" ] && [ -n "$(git ls-files --others --exclude-standard "$DOCS_DIR" 2>/dev/null)" ]; then
  needs_fix=true
fi

if [ "$needs_fix" = true ]; then
  case "$DOCS_MODE" in
    stash)
      say "Stashing tracked + untracked changes (safe default)…"
      git add -A
      git stash push --include-untracked -m "pre-merge backup $(date -u +%Y%m%dT%H%M%SZ)"
      ;;
    commit)
      say "Committing local docs before pull…"
      git add -A
      git commit -m "chore: add local docs before upstream pull"
      ;;
    backup)
      say "Backing up untracked docs to _premerge_backup/ then cleaning worktree…"
      mkdir -p _premerge_backup
      rsync -a --ignore-existing "$DOCS_DIR"/ _premerge_backup/docs/ 2>/dev/null || true
      # clean only untracked files
      git clean -fd
      ;;
    *)
      die "Unknown DOCS_MODE=$DOCS_MODE"
      ;;
  esac
fi

# --- Step 2: fast-forward main, then continue on our branch rebased
say "Fast-forwarding $TARGET_BRANCH from $PUSH_REMOTE/$TARGET_BRANCH…"
git checkout "$TARGET_BRANCH"
git pull --ff-only
git checkout "$BRANCH"
git rebase "$TARGET_BRANCH"

# --- Step 3: add or fetch the swarm remote
if git remote get-url swarm >/dev/null 2>&1; then
  say "remote 'swarm' exists"
else
  git remote add swarm "$SWARM_REPO"
fi
git fetch swarm --tags

# --- Step 4: first-time subtree add (preserve history); fallback to subtree-merge strategy if needed
# Docs: subtree merges & unrelated histories flags. (see GitHub docs + git-merge --allow-unrelated-histories)
subtree_add() {
  say "subtree add -> ${STAGING_PREFIX} from swarm/$SWARM_BRANCH"
  git subtree add --prefix="$STAGING_PREFIX" swarm "$SWARM_BRANCH" -m "feat(subtree): add swarm@$SWARM_BRANCH"
}
subtree_merge_strategy() {
  say "fallback: subtree-merge strategy (ours + read-tree --prefix)"
  git merge -s ours --no-commit --allow-unrelated-histories "swarm/$SWARM_BRANCH" || true
  git read-tree --prefix="${STAGING_PREFIX}/" -u "swarm/$SWARM_BRANCH"
  git commit -m "Subtree merged in ${STAGING_PREFIX} from swarm/$SWARM_BRANCH"
}

# If a previous subtree exists, pull; else add
HAS_SUBTREE_META="false"
git log --grep="git-subtree-dir: ${STAGING_PREFIX}" -n 1 >/dev/null 2>&1 && HAS_SUBTREE_META="true"

if [ "$HAS_SUBTREE_META" = "true" ]; then
  say "existing subtree found; pulling updates"
  if ! git subtree pull --prefix="$STAGING_PREFIX" swarm "$SWARM_BRANCH" -m "chore(subtree): pull swarm@$SWARM_BRANCH" 2>/tmp/subtree.err; then
    if grep -qi "refusing to merge unrelated histories" /tmp/subtree.err; then
      subtree_merge_strategy
    else
      cat /tmp/subtree.err >&2; die "subtree pull failed"
    fi
  fi
else
  if ! subtree_add 2>/tmp/subtree.err; then
    if grep -qi "refusing to merge unrelated histories" /tmp/subtree.err; then
      subtree_merge_strategy
    else
      cat /tmp/subtree.err >&2; die "subtree add failed"
    fi
  fi
fi

# --- Step 5: move into safe homes inside construct-iq
mkdir -p services/agents apps docs/swarm ops/swarm infra/swarm .github/workflows templates/swarm

move_if_exists () {
  local src="$1" dst="$2"
  if [ -d "${STAGING_PREFIX}/${src}" ]; then
    say "moving ${src} -> ${dst}"
    mkdir -p "$(dirname "$dst")"
    git mv "${STAGING_PREFIX}/${src}" "$dst"
  fi
}
move_if_exists memory-gateway      services/memory-gateway
move_if_exists orchestrator        services/orchestrator
move_if_exists agents              services/agents
move_if_exists dashboard           apps/swarm-dashboard
move_if_exists scripts             ops/swarm
move_if_exists docs                docs/swarm
move_if_exists gcs                 infra/swarm
move_if_exists templates           templates/swarm
move_if_exists langchain-runtime   services/agents/langchain-runtime
move_if_exists financial-agent     services/agents/financial-agent
move_if_exists strategist-agent    services/agents/strategist-agent
move_if_exists visionary-agent     services/agents/visionary-agent

# Namespace CI workflows
if [ -d "${STAGING_PREFIX}/ci/github-actions" ]; then
  say "namespacing CI → .github/workflows/swarm-*.yml"
  tmpdir="$(mktemp -d)"
  cp -r "${STAGING_PREFIX}/ci/github-actions/." "$tmpdir/"
  for f in "$tmpdir"/*.yml "$tmpdir"/*.yaml 2>/dev/null; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    mv "$f" ".github/workflows/swarm-${base}"
    git add ".github/workflows/swarm-${base}"
  done
  rm -rf "$tmpdir"
fi

# Keep staging if leftovers remain
if [ -d "$STAGING_PREFIX" ] && [ -z "$(ls -A "$STAGING_PREFIX" 2>/dev/null)" ]; then
  git rm -r "$STAGING_PREFIX"
fi

# Migration map breadcrumb
cat > MIGRATION_SWARM_MAP.md << 'MAP'
Mapping (swarm -> construct-iq):
- memory-gateway -> services/memory-gateway
- orchestrator -> services/orchestrator
- agents/* -> services/agents/*
- dashboard -> apps/swarm-dashboard
- scripts -> ops/swarm
- docs/* -> docs/swarm/*
- ci/github-actions/* -> .github/workflows/swarm-*.yml
- gcs/* -> infra/swarm/*
- templates/* -> templates/swarm/*
MAP
git add MIGRATION_SWARM_MAP.md

git commit -m "feat(merge): land infinity-x-one-swarm via subtree into safe paths"

# --- Step 6: smoke summary + push
echo
echo "================ MERGE SMOKE SUMMARY ================"
git status -s
echo
git --no-pager log --oneline --decorate --graph -n 25
echo
ls -la | sed 's/^/  /'
echo "====================================================="
say "pushing $BRANCH -> $PUSH_REMOTE"
git push -u "$PUSH_REMOTE" "$BRANCH"

echo
echo "[✓] Review branch ready: $BRANCH  → open PR into $TARGET_BRANCH"
echo "    If you used DOCS_MODE=stash, you can inspect your stash via:  git stash list"
echo "    and re-apply selectively with:  git stash show -p | git apply -R  (or 'git stash pop')."
