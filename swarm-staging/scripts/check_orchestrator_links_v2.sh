#!/bin/bash
# Infinity-X One: Orchestrator Audit (v2)
# Fixed: yq missing + updated logging command

PROJECT="infinity-x-one-swarm-system"
REGION="us-east1"
SERVICE="orchestrator"
DEST="$HOME/infinity-x-one-swarm"
REPORT="$DEST/ORCHESTRATOR_AUDIT_REPORT.md"

echo "🧭 Checking existing Orchestrator connections in project: $PROJECT"
echo "📅 Started at: $(date)"
echo "============================================================="

mkdir -p "$DEST"

# Auto-install yq if missing
if ! command -v yq &> /dev/null; then
  echo "📦 Installing yq (YAML processor)..."
  sudo apt-get update -y >/dev/null 2>&1
  sudo apt-get install -y yq >/dev/null 2>&1
fi

# 1️⃣ Describe the Cloud Run service
echo "🔹 Fetching Orchestrator service info..."
gcloud run services describe $SERVICE \
  --project $PROJECT --region $REGION \
  --format="yaml" > "$DEST/orchestrator_config.yaml"

URL=$(yq '.status.url' "$DEST/orchestrator_config.yaml" 2>/dev/null)
IMAGE=$(yq '.spec.template.spec.containers[0].image' "$DEST/orchestrator_config.yaml" 2>/dev/null)
REVISION=$(yq '.status.latestReadyRevisionName' "$DEST/orchestrator_config.yaml" 2>/dev/null)

echo "✅ Endpoint: ${URL:-unknown}"
echo "✅ Image: ${IMAGE:-unknown}"
echo "✅ Revision: ${REVISION:-unknown}"
echo "-------------------------------------------------------------"

# 2️⃣ Check health endpoint
if [ -n "$URL" ]; then
  echo "🔹 Checking /health ..."
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL/health")
  if [[ "$STATUS" == "200" ]]; then
    echo "💚 Healthy (HTTP 200)"
  else
    echo "⚠️  /health returned status: $STATUS"
  fi
fi
echo "-------------------------------------------------------------"

# 3️⃣ Extract environment vars
echo "🔹 Checking environment variables..."
gcloud run services describe $SERVICE \
  --project $PROJECT --region $REGION \
  --format="value(spec.template.spec.containers[0].env)" > "$DEST/orchestrator_env_raw.txt"

grep -o 'name: [A-Z0-9_]\+' "$DEST/orchestrator_env_raw.txt" | awk '{print $2}' > "$DEST/orchestrator_env_names.txt"
echo "🔍 Found environment vars:"
cat "$DEST/orchestrator_env_names.txt" | sed 's/^/   • /'
echo "-------------------------------------------------------------"

# 4️⃣ Detect linked agents
echo "🔹 Detecting linked agents..."
AGENTS=(VISIONARY_AGENT_URL STRATEGIST_AGENT_URL FINANCIAL_AGENT_URL CODEX_AGENT_URL INFINITY_AGENT_URL MEMORY_GATEWAY_URL HEADLESS_API_URL)
FOUND_LINKS=()

for agent in "${AGENTS[@]}"; do
  if grep -q "$agent" "$DEST/orchestrator_env_raw.txt"; then
    FOUND_LINKS+=("$agent")
  fi
done

if [ ${#FOUND_LINKS[@]} -eq 0 ]; then
  echo "❌ No linked agents found in environment variables."
else
  echo "✅ Linked agents detected:"
  for a in "${FOUND_LINKS[@]}"; do echo "   • $a"; done
fi
echo "-------------------------------------------------------------"

# 5️⃣ Scan logs for outbound calls (using new syntax)
echo "🔹 Scanning recent logs for outbound calls..."
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE" \
  --project=$PROJECT \
  --limit=50 \
  --format="value(httpRequest.requestUrl)" \
  | grep -E "https://" | sort -u > "$DEST/orchestrator_outgoing_urls.txt"

if [ -s "$DEST/orchestrator_outgoing_urls.txt" ]; then
  echo "🌐 Outgoing URLs:"
  cat "$DEST/orchestrator_outgoing_urls.txt" | sed 's/^/   → /'
else
  echo "ℹ️ No outbound connections detected."
fi

echo "-------------------------------------------------------------"

# 6️⃣ Write report
echo "🧾 Saving report → $REPORT"
cat > "$REPORT" <<EOF
# Infinity-X One — Orchestrator Audit Report (v2)
**Project:** $PROJECT  
**Region:** $REGION  
**Timestamp:** $(date)

## Basic Info
- Endpoint: ${URL:-unknown}
- Image: ${IMAGE:-unknown}
- Revision: ${REVISION:-unknown}

## Linked Agents
$(if [ ${#FOUND_LINKS[@]} -eq 0 ]; then echo "None detected."; else printf '%s\n' "${FOUND_LINKS[@]}"; fi)

## Health
$(if [ "$STATUS" == "200" ]; then echo "Healthy ✅"; else echo "Unhealthy ⚠️"; fi)

## Outgoing URLs
$(cat "$DEST/orchestrator_outgoing_urls.txt" | sed 's/^/• /')
EOF

echo "✅ Audit complete."
echo "📄 Report: $REPORT"
echo "============================================================="

