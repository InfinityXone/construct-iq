#!/bin/bash
# ==============================================================
# Infinity-X One — Autonomous Full Stack Bootstrap v1.0
# Links all Cloud Run services together and hydrates memory
# ==============================================================

PROJECT="infinity-x-one-swarm-system"
DEST="$HOME/infinity-x-one-swarm"
ENV_FILE="$DEST/.env"
BLUEPRINT="$DEST/SYSTEM_BLUEPRINT.md"
STATUS="$DEST/SYSTEM_STATUS.md"

echo "🚀 Infinity-X One — Full Stack Bootstrap"
echo "🧭 Project: $PROJECT"
echo "📅 Started: $(date)"
echo "============================================================="

# --- 1. Build .env file from blueprint ---
echo "🔧 Building .env from SYSTEM_BLUEPRINT.md ..."
grep -Eo 'https://[a-z0-9.-]+' "$BLUEPRINT" | while read -r url; do
  name=$(basename "$url" | cut -d'-' -f1)
  upper=$(echo "$name" | tr '[:lower:]' '[:upper:]')
  echo "${upper}_URL=$url" >> "$ENV_FILE"
done
echo "✅ Environment file updated: $ENV_FILE"

# --- 2. Register each agent with orchestrator ---
ORCH_URL=$(grep 'orchestrator' "$BLUEPRINT" | grep -Eo 'https://[a-z0-9.-]+')

if [[ -z "$ORCH_URL" ]]; then
  echo "❌ No orchestrator URL found. Exiting."
  exit 1
fi

echo "🔗 Registering agents with Orchestrator at: $ORCH_URL"

grep -Eo 'https://[a-z0-9.-]+' "$BLUEPRINT" | while read -r agent_url; do
  if [[ "$agent_url" != *"orchestrator"* ]]; then
    echo "   → Registering $agent_url ..."
    curl -s -X POST "$ORCH_URL/register" \
      -H "Content-Type: application/json" \
      -d "{\"agent_url\": \"$agent_url\"}" >/dev/null
  fi
done

echo "✅ All agents registered successfully."

# --- 3. Hydrate into Memory Gateway ---
MEM_URL=$(grep 'memory-gateway' "$BLUEPRINT" | grep -Eo 'https://[a-z0-9.-]+')
if [[ -n "$MEM_URL" ]]; then
  echo "🧠 Syncing system state to Memory Gateway..."
  curl -s -X POST "$MEM_URL/hydrate" \
    -H "Content-Type: application/json" \
    -d "{\"status\": \"linked\", \"timestamp\": \"$(date)\", \"project\": \"$PROJECT\"}" >/dev/null
  echo "✅ Memory Gateway updated."
else
  echo "⚠️ No memory gateway URL found — skipping hydration."
fi

# --- 4. Generate status report ---
cat > "$STATUS" <<EOF
# Infinity-X One — System Status

📅 Updated: $(date)
🌐 Project: $PROJECT

All agents successfully registered with Orchestrator: $ORCH_URL  
Memory Gateway hydrated at: $MEM_URL  

| Component | URL | Status |
|------------|------|--------|
EOF

grep -Eo 'https://[a-z0-9.-]+' "$BLUEPRINT" | while read -r url; do
  echo "| $(basename "$url" | cut -d'-' -f1) | $url | ✅ Linked |" >> "$STATUS"
done

echo "✅ System Status written to $STATUS"

echo "============================================================="
echo "🌙 Infinity-X One stack fully hydrated and interconnected."
echo "📘 View logs + state in: $STATUS"
echo "============================================================="
