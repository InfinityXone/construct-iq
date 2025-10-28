#!/usr/bin/env bash
# finish_swarm_import.sh — create the subtree (first import) then move into safe homes.
# If 'subtree add' fails with unrelated histories, use the subtree-merge fallback.

set -Eeuo pipefail

SWARM_REMOTE="${SWARM_REMOTE:-swarm}"
SWARM_REPO="${SWARM_REPO:-https://github.com/InfinityXone/infinity-x-one-swarm.git}"
SWARM_BRANCH="${SWARM_BRANCH:-main}"
STAGING_PREFIX="${STAGING_PREFIX:-swarm-staging}"
PUSH_REMOTE="${PUSH_REMOTE:-origin}"

say(){ echo "[i] $*"; }
die(){ echo "ERROR: $*" >&2; exit 1; }

command -v git >/dev/null || die "git required"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "run inside a git repo"

# ensure remote exists
if git remote get-url "$SWARM_REMOTE" >/dev/null 2>&1; then
  say "remote '$SWARM_REMOTE' exists"
else
  say "adding remote '$SWARM_REMOTE' -> $SWARM_REPO"
  git remote add "$SWARM_REMOTE" "$SWARM_REPO"
fi
git fetch "$SWARM_REMOTE" --tags

# if staging dir not present, this is a first import — do subtree add
if [ ! -d "$STAGING_PREFIX" ]; then
  say "first import: git subtree add --prefix=$STAGING_PREFIX $SWARM_REMOTE $SWARM_BRANCH"
  if ! git subtree add --prefix="$STAGING_PREFIX" "$SWARM_REMOTE" "$SWARM_BRANCH" -m "feat(subtree): add $SWARM_REMOTE@$SWARM_BRANCH" 2>/tmp/subtree.err; then
    if grep -qi "refusing to merge unrelated histories" /tmp/subtree.err; then
      say "fallback: subtree-merge strategy (ours + read-tree --prefix)"
      git merge -s ours --no-commit --allow-unrelated-histories "$SWARM_REMOTE/$SWARM_BRANCH" || true
      git read-tree --prefix="${STAGING_PREFIX}/" -u "$SWARM_REMOTE/$SWARM_BRANCH"
      git commit -m "Subtree merged in ${STAGING_PREFIX} from $SWARM_REMOTE/$SWARM_BRANCH"
    else
      cat /tmp/subtree.err >&2; die "subtree add failed"
    fi
  fi
else
  say "$STAGING_PREFIX already exists; skipping add."
fi

# create destinations and move mapped folders
mkdir -p services/agents apps docs/swarm ops/swarm infra/swarm .github/workflows templates/swarm

move_if () {
  local src="$1" dst="$2"
  if [ -d "${STAGING_PREFIX}/${src}" ]; then
    say "moving ${src} -> ${dst}"
    mkdir -p "$(dirname "$dst")"
    git mv "${STAGING_PREFIX}/${src}" "$dst"
  fi
}

move_if memory-gateway      services/memory-gateway
move_if orchestrator        services/orchestrator
move_if agents              services/agents
move_if dashboard           apps/swarm-dashboard
move_if scripts             ops/swarm
move_if docs                docs/swarm
move_if gcs                 infra/swarm
move_if templates           templates/swarm
move_if langchain-runtime   services/agents/langchain-runtime
move_if financial-agent     services/agents/financial-agent
move_if strategist-agent    services/agents/strategist-agent
move_if visionary-agent     services/agents/visionary-agent

# namespace CI workflows
if [ -d "${STAGING_PREFIX}/ci/github-actions" ]; then
  say "namespacing CI → .github/workflows/swarm-*.yml"
  tmpdir="$(mktemp -d)"
  cp -r "${STAGING_PREFIX}/ci/github-actions/." "$tmpdir/"
  for f in "$tmpdir"/*.yml "$tmpdir"/*.yaml 2>/dev/null; do
    [ -f "$f" ] || continue
    mv "$f" ".github/workflows/swarm-$(basename "$f")"
    git add ".github/workflows/swarm-$(basename "$f")"
  done
  rm -rf "$tmpdir"
fi

# breadcrumb
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

# drop empty staging dir
if [ -d "$STAGING_PREFIX" ] && [ -z "$(ls -A "$STAGING_PREFIX" 2>/dev/null)" ]; then
  git rm -r "$STAGING_PREFIX"
fi

git commit -m "feat(merge): land infinity-x-one-swarm into safe paths"

echo
echo "================ MERGE SMOKE SUMMARY ================"
git status -s
echo
git --no-pager log --oneline --decorate --graph -n 20
echo
ls -la | sed 's/^/  /'
echo "====================================================="

# push the current branch (you already created it earlier)
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
say "pushing $BRANCH -> $PUSH_REMOTE"
git push -u "$PUSH_REMOTE" "$BRANCH"

echo
echo "[✓] Review branch ready: $BRANCH — open PR into $(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} | cut -d/ -f2 || echo main)"
