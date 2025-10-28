#!/bin/bash
set +e

echo "💧 Infinity-X One Hydration + Diagnostics v4"
PROJECT_DIR="$HOME/infinity-x-one-swarm"
PROJECT_ID="infinity-x-one-swarm-system"
BUCKET="gs://infinity-x-one-swarm-system-memory"
GATEWAY_URL="https://memory-gateway-ru6asaa7vq-ue.a.run.app"
SUMMARY="$PROJECT_DIR/HYDRATION_SUMMARY.md"
LOG="$PROJECT_DIR/HYDRATION_LOG.txt"
HISTORY="$PROJECT_DIR/HYDRATION_HISTORY.md"

echo "🧭 Running system check at $(date)" | tee "$LOG"

# --- Core Checks ---
declare -A CHECKS=(
  ["scripts"]=0
  ["orchestrator"]=0
  ["memory-gateway"]=0
  ["langchain-runtime"]=0
  ["strategist-agent"]=0
  ["visionary-agent"]=0
  ["dashboard"]=0
  ["financial-agent"]=0
)
TOTAL=${#CHECKS[@]}
FOUND=0

echo "📂 Verifying structure..."
for key in "${!CHECKS[@]}"; do
  path="$PROJECT_DIR/$key"
  if [ -d "$path" ]; then
    echo "✅ Found: $key" | tee -a "$LOG"
    ((FOUND++))
  else
    echo "⚠️ Missing: $key" | tee -a "$LOG"
  fi
done

STRUCT_SCORE=$((FOUND * 100 / TOTAL))

# --- Cloud Health ---
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL" || echo "000")
if [ "$STATUS" == "200" ]; then
  CLOUD_SCORE=100
else
  CLOUD_SCORE=30
fi

# --- Repo Health ---
cd "$PROJECT_DIR"
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  REPO_SCORE=100
else
  REPO_SCORE=0
fi

# --- Compute Overall ---
OVERALL=$(( (STRUCT_SCORE + CLOUD_SCORE + REPO_SCORE) / 3 ))

# --- Visual Rating ---
if (( OVERALL >= 90 )); then BAR="🟩🟩🟩🟩🟩"; LEVEL="FULL PRODUCTION"
elif (( OVERALL >= 70 )); then BAR="🟩🟩🟩🟨⬜"; LEVEL="STABLE"
elif (( OVERALL >= 50 )); then BAR="🟩🟨⬜⬜⬜"; LEVEL="PARTIAL"
else BAR="🟥⬜⬜⬜⬜"; LEVEL="CRITICAL"; fi

# --- Recommendations ---
RECS=()
(( STRUCT_SCORE < 100 )) && RECS+=("Add missing core directories (see ⚠️ entries).")
(( CLOUD_SCORE < 100 )) && RECS+=("Check Cloud Run Memory Gateway health or redeploy.")
(( REPO_SCORE < 100 )) && RECS+=("Initialize or fix Git repository.")
RECS+=("Add auto-scaling orchestrator agents based on Omega StrategyGPT plan.")
RECS+=("Integrate Supabase analytics and mission logs as per 24/7 mode.")

# --- Write Summary ---
{
  echo "# 🧠 Infinity-X Hydration Report v4"
  echo "🕒 $(date)"
  echo ""
  echo "### 📊 Scores"
  echo "- Structure: $STRUCT_SCORE%"
  echo "- Cloud: $CLOUD_SCORE%"
  echo "- Repo: $REPO_SCORE%"
  echo "- **Overall: $OVERALL% ($LEVEL)** $BAR"
  echo ""
  echo "### ⚠️ Missing Components"
  grep "⚠️ Missing" "$LOG" || echo "- None"
  echo ""
  echo "### 🧩 Recommended Optimizations"
  for r in "${RECS[@]}"; do echo "- $r"; done
  echo ""
  echo "### 🪵 Log tail"
  tail -n 10 "$LOG"
} > "$SUMMARY"

# --- Append to history ---
echo "$(date): $OVERALL% — $LEVEL" >> "$HISTORY"

echo "✅ Completed diagnostics."
echo "📊 $OVERALL% — $LEVEL"
echo "📜 Summary → $SUMMARY"
echo "📈 History logged → $HISTORY"
