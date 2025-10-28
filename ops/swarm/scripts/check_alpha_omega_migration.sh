#!/bin/bash
# ==============================================================
# 🧭 Infinity-X One — Alpha → Omega Stack Migration Checker
# ==============================================================
# Compares old Alpha–Omega stack folder with new Infinity-X One Swarm repo
# Checks for files not migrated, structure gaps, and mismatched module states.

OLD_STACK="$HOME/alpha-omega-stack"
NEW_REPO="$HOME/infinity-x-one-swarm"
DATE=$(date "+%Y-%m-%d %H:%M:%S")
LOG="$NEW_REPO/ALPHA_OMEGA_MIGRATION_LOG.txt"
SUMMARY="$NEW_REPO/ALPHA_OMEGA_MIGRATION_SUMMARY.md"

echo "🧭 Migration Check — $DATE" | tee "$LOG"
echo "🔹 Old Stack: $OLD_STACK" | tee -a "$LOG"
echo "🔹 New Repo:  $NEW_REPO" | tee -a "$LOG"
echo "=============================================================" | tee -a "$LOG"

# --- 1️⃣ Sanity checks ---
if [ ! -d "$OLD_STACK" ]; then
  echo "❌ ERROR: Old stack directory not found at $OLD_STACK" | tee -a "$LOG"
  exit 1
fi
if [ ! -d "$NEW_REPO" ]; then
  echo "❌ ERROR: New repo directory not found at $NEW_REPO" | tee -a "$LOG"
  exit 1
fi

# --- 2️⃣ Compare directory structure ---
echo "📂 Comparing directory trees..." | tee -a "$LOG"
OLD_TREE="$NEW_REPO/OLD_STACK_TREE.txt"
NEW_TREE="$NEW_REPO/NEW_REPO_TREE.txt"
diff_file="$NEW_REPO/STACK_DIFF.txt"

tree -I ".git|node_modules|.venv|__pycache__" "$OLD_STACK" > "$OLD_TREE" 2>/dev/null
tree -I ".git|node_modules|.venv|__pycache__" "$NEW_REPO" > "$NEW_TREE" 2>/dev/null

diff -u "$OLD_TREE" "$NEW_TREE" > "$diff_file" || true
echo "🧩 Directory comparison written to $diff_file" | tee -a "$LOG"

# --- 3️⃣ Identify missing or new files ---
echo "🔎 Scanning for missing files..." | tee -a "$LOG"
MISSING_COUNT=0
FOUND_COUNT=0

while IFS= read -r f; do
  REL_PATH="${f#$OLD_STACK/}"
  if [ -f "$NEW_REPO/$REL_PATH" ]; then
    ((FOUND_COUNT++))
  else
    ((MISSING_COUNT++))
    echo "⚠️ Missing in new repo: $REL_PATH" | tee -a "$LOG"
  fi
done < <(find "$OLD_STACK" -type f)

TOTAL_OLD=$(find "$OLD_STACK" -type f | wc -l)
MIGRATED_PERCENT=$(( FOUND_COUNT * 100 / TOTAL_OLD ))

# --- 4️⃣ Generate summary report ---
{
  echo "# 🔁 Alpha → Omega Migration Summary"
  echo "### Timestamp: $DATE"
  echo ""
  echo "## 📂 Directories"
  echo "- Old Stack: $OLD_STACK"
  echo "- New Repo:  $NEW_REPO"
  echo ""
  echo "## 🧩 Migration Stats"
  echo "- Files in old stack: $TOTAL_OLD"
  echo "- Files found in new repo: $FOUND_COUNT"
  echo "- Files missing: $MISSING_COUNT"
  echo "- Migration completeness: **$MIGRATED_PERCENT%**"
  echo ""
  echo "## ⚠️ Missing Files (first 10)"
  grep '⚠️ Missing' "$LOG" | head -n 10 || echo "- None"
  echo ""
  echo "## 🪵 Full details"
  echo "- Directory diff: $diff_file"
  echo "- Log file: $LOG"
} > "$SUMMARY"

echo "✅ Migration summary written to $SUMMARY" | tee -a "$LOG"
echo "🏁 Migration check complete." | tee -a "$LOG"
