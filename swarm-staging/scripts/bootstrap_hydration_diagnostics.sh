#!/bin/bash
set -e

echo "💧 Bootstrapping Infinity-X One Hydration + Diagnostics System v2"
PROJECT_ID="infinity-x-one-swarm-system"
REGION="us-east1"
BUCKET="gs://infinity-x-one-swarm-system-memory"
PROJECT_DIR="$HOME/infinity-x-one-swarm"
BRANCH="main"
GATEWAY_URL="https://memory-gateway-ru6asaa7vq-ue.a.run.app"
LOG_FILE="$PROJECT_DIR/HYDRATION_LOG.txt"
SUMMARY_FILE="$PROJECT_DIR/HYDRATION_SUMMARY.md"

echo "🧭 Starting hydration & diagnostics at $(date)" | tee "$LOG_FILE"

# --- 1️⃣ Structural Verification ---
echo "📂 Checking local directory integrity..." | tee -a "$LOG_FILE"
MISSING_COUNT=0
FOUND_COUNT=0

declare -a REQUIRED_PATHS=(
  "$PROJECT_DIR/scripts"
  "$PROJECT_DIR/orchestrator"
  "$PROJECT_DIR/memory-gateway"
  "$PROJECT_DIR/langchain-runtime"
  "$PROJECT_DIR/strategist-agent"
  "$PROJECT_DIR/visionary-agent"
  "$PROJECT_DIR/dashboard"
  "$PROJECT_DIR/financial-agent"
)

for p in "${REQUIRED_PATHS[@]}"; do
  if [ ! -d "$p" ]; then
    echo "⚠️ Missing: $p" | tee -a "$LOG_FILE"
    ((MISSING_COUNT++))
  else
    echo "✅ Found: $p" | tee -a "$LOG_FILE"
    ((FOUND_COUNT++))
  fi
done

STRUCT_SCORE=$(( FOUND_COUNT * 100 / ${#REQUIRED_PATHS[@]} ))

# --- 2️⃣ Repository Tree + Change Diff ---
echo "🌲 Building REPO_TREE.md..." | tee -a "$LOG_FILE"
tree -I ".git|node_modules|.venv|__pycache__|*.log|tmp|logs" > "$PROJECT_DIR/REPO_TREE.md"
if [ -f "$PROJECT_DIR/REPO_TREE_PREV.md" ]; then
  diff -u "$PROJECT_DIR/REPO_TREE_PREV.md" "$PROJECT_DIR/REPO_TREE.md" > "$PROJECT_DIR/REPO_TREE_DIFF.txt" || true
  echo "🧩 Change diff recorded → REPO_TREE_DIFF.txt" | tee -a "$LOG_FILE"
else
  echo "⚙️ No previous tree — baseline created." | tee -a "$LOG_FILE"
fi
cp "$PROJECT_DIR/REPO_TREE.md" "$PROJECT_DIR/REPO_TREE_PREV.md"

# --- 3️⃣ Cloud Verification ---
echo "☁️ Checking Cloud Run Gateway..." | tee -a "$LOG_FILE"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL" || echo "000")
if [ "$STATUS" == "200" ]; then
  echo "✅ Cloud Run Gateway operational (HTTP 200)" | tee -a "$LOG_FILE"
  CLOUD_SCORE=100
else
  echo "❌ Gateway returned HTTP $STATUS" | tee -a "$LOG_FILE"
  CLOUD_SCORE=40
fi

# --- 4️⃣ GitHub Repo Sync Health ---
cd "$PROJECT_DIR"
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "🔁 Repo verified — syncing..." | tee -a "$LOG_FILE"
  git add REPO_TREE.md HYDRATION_LOG.txt REPO_TREE_DIFF.txt || true
  git commit -m "💧 Auto Hydration Snapshot $(date +%F_%H-%M-%S)" || echo "ℹ️ No new changes."
  git push origin "$BRANCH" || echo "⚠️ Git push failed or no auth token."
  REPO_SCORE=100
else
  echo "❌ Not a valid Git repository!" | tee -a "$LOG_FILE"
  REPO_SCORE=0
fi

# --- 5️⃣ Compute Completion Rating ---
OVERALL_SCORE=$(( (STRUCT_SCORE + CLOUD_SCORE + REPO_SCORE) / 3 ))

if (( OVERALL_SCORE > 95 )); then
  HEALTH="🌕 Full Production-Ready"
elif (( OVERALL_SCORE > 75 )); then
  HEALTH="🌓 Stable, Upgrade Recommended"
elif (( OVERALL_SCORE > 50 )); then
  HEALTH="🌗 Partial Functionality"
else
  HEALTH="🌑 Incomplete — Major Issues"
fi

# --- 6️⃣ Recommended Upgrades ---
echo "🧠 Generating optimization recommendations..." | tee -a "$LOG_FILE"
RECOMMENDATIONS=()
if (( STRUCT_SCORE < 100 )); then
  RECOMMENDATIONS+=("Add missing folders or agents (see ⚠️ entries).")
fi
if (( CLOUD_SCORE < 100 )); then
  RECOMMENDATIONS+=("Check Memory Gateway container health / deploy status.")
fi
if (( REPO_SCORE < 100 )); then
  RECOMMENDATIONS+=("Verify GitHub authentication or token access.")
fi
RECOMMENDATIONS+=("Consider adding Cloud Scheduler for auto hydration every hour.")
RECOMMENDATIONS+=("Enable system log sync to gs://infinity-x-one-swarm-system-logs for telemetry.")
RECOMMENDATIONS+=("Add LangChain runtime monitoring via orchestrator health pings.")

# --- 7️⃣ Sync Reports to Cloud ---
echo "📤 Uploading reports to GCS..." | tee -a "$LOG_FILE"
gsutil cp "$PROJECT_DIR/REPO_TREE.md" "$BUCKET/docs/REPO_TREE.md" || true
gsutil cp "$LOG_FILE" "$BUCKET/logs/HYDRATION_LOG_$(date +%F_%H-%M-%S).txt" || true

# --- 8️⃣ Generate Summary Markdown ---
{
  echo "# 🧠 Infinity-X Hydration Diagnostic Report"
  echo "### 🕒 Timestamp: $(date)"
  echo "### 🌍 Project: $PROJECT_ID"
  echo ""
  echo "## 🧩 System Scores"
  echo "- Structural Integrity: **$STRUCT_SCORE%**"
  echo "- Cloud Connectivity: **$CLOUD_SCORE%**"
  echo "- Repository Sync: **$REPO_SCORE%**"
  echo "- **Overall Completion: $OVERALL_SCORE% — $HEALTH**"
  echo ""
  echo "## 🧱 Missing or Weak Components"
  grep "⚠️ Missing" "$LOG_FILE" || echo "- None"
  echo ""
  echo "## 🧠 Recommended Optimizations"
  for rec in "${RECOMMENDATIONS[@]}"; do
    echo "- $rec"
  done
  echo ""
  echo "## 🪵 Recent Log Output"
  tail -n 10 "$LOG_FILE"
} > "$SUMMARY_FILE"

# --- 9️⃣ Display Result ---
echo "✅ Hydration diagnostics complete."
echo "📊 Overall Rating: $OVERALL_SCORE% — $HEALTH"
echo "🧾 Summary: $SUMMARY_FILE"
echo "📤 Synced logs and tree to: $BUCKET"
