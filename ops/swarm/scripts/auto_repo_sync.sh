#!/usr/bin/env bash
# auto_repo_sync.sh
# Commits & pushes verified changes while keeping repo clean.

set -euo pipefail
cd "$HOME/infinity-x-one-swarm"
LOG="$HOME/infinity-x-one-swarm/memory-gateway/REPO_SYNC_LOG.txt"

echo "🚀 [$(date -u)] Starting automated repository sync..." | tee -a "$LOG"

# --- Clean transient and log files ------------------------------------------
echo "🧹 Cleaning transient logs and temporary files..." | tee -a "$LOG"
find . -type f \( -name "*.log" -o -name "*.txt" -o -name "*.tar.gz" \) ! -path "./memory-gateway/*" -delete || true
find . -type f -size 0 -delete || true

# --- Stage only relevant files ----------------------------------------------
git add -A
git reset -- scripts/*.log *.txt *.tar.gz || true

# --- Commit changes ---------------------------------------------------------
if ! git diff --cached --quiet; then
  COMMIT_MSG="🤖 Auto-sync: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  git commit -m "$COMMIT_MSG" | tee -a "$LOG"
  echo "📤 Pushing to remote..." | tee -a "$LOG"
  git push | tee -a "$LOG"
else
  echo "✅ No changes to commit." | tee -a "$LOG"
fi

echo "🧠 [$(date -u)] Repository sync complete." | tee -a "$LOG"
