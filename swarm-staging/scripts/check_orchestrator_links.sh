#!/bin/bash
# Check existing Orchestrator Cloud Run service for linkage and dependencies
# Safe: read-only, does not deploy or edit anything.

PROJECT="infinity-x-one-swarm-system"
REGION="us-east1"
SERVICE="orchestrator"
DEST="$HOME/infinity-x-one-swarm"
REPORT="$DEST/ORCHESTRATOR_AUDIT_REPORT.md"

echo "🧭 Checking existing Orchestrator connections in project: $PROJECT"
echo "📅 Started at: $(date)"
echo "============================================================="

mkdir -p "$DEST"

# 1️⃣ Basic Service Info
echo "🔹 Fetching Orchestrator service info..."
gcloud run services describe $SERVICE \
  --project $PROJECT --region $REGION \
  --format="yaml" > "$DEST/orchestrator_config.yaml"

# Extract endpoint + image + revision
URL=$(yq '.status.url' "$DEST/orchestrator_config.yaml")
IMAGE=$(yq '.spec.template.spec.containers[0].image' "$DEST/orchestrator_config.yaml")
REVISION=$(yq '.status.latestReadyRevisionName' "$DEST/orchestrator_config.yaml")

echo "✅ Endpoint: $URL"
echo "✅ Image: $IMAGE"
echo "✅ Revision: $REVISION"
echo "-------------------------------------------------------------"

# 2️⃣ Check Health Endpoint
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

# 3️⃣ Environment Variables
echo "🔹 Checking environment variables..."
gcloud run services describe $SERVICE \
  --project $PROJECT --region $REGION \
  --format="value(spec.template.spec.containers[0].env)" > "$DEST/orchestrator_env_raw.txt"

grep -o 'name: [A-Z0-9_]\+' "$DEST/orchestrator_env_raw.txt" | awk '{print $2}' > "$DEST/orchestrator_env_names.txt"

echo "🔍 Found environment vars:"
cat "$DEST/orchestrator_env_names.txt" | sed 's/^/   • /'
echo "-------------------------------------------------------------"

# 4️⃣ Detect if Orchestrator is linked to known agents
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
  for a in "${FOUND_LINKS[@]}"; do
    echo "   • $a"
  done
fi
echo "-------------------------------------------------------------"

# 5️⃣ Check logs for outgoing connections (last 50 requests)
echo "🔹 Scanning recent logs for agent calls..."
gcloud logs read "projects/$PROJECT/logs/run.googleapis.com%2Frequests" \
  --project $PROJECT \
  --limit 50 \
  --format="value(httpRequest.requestUrl)" \
  --filter="resource.labels.service_name=$SERVICE" \
  | grep -E "https://" | sort -u > "$DEST/orchestrator_outgoing_urls.txt"

if [ -s "$DEST/orchestrator_outgoing_urls.txt" ]; then
  echo "🌐 Outgoing URLs in recent logs:"
  cat "$DEST/orchestrator_outgoing_urls.txt" | sed 's/^/   → /'
else
  echo "ℹ️ No outgoing requests found in recent logs."
fi

echo "-------------------------------------------------------------"

# 6️⃣ Save audit report
echo "🧾 Saving summary to $REPORT"
cat > "$REPORT" <<EOF
# 🧭 Orchestrator Audit Report
**Project:** $PROJECT  
**Region:** $REGION  
**Timestamp:** $(date)

## Basic Info
- Endpoint: $URL
- Image: $IMAGE
- Revision: $REVISION

## Linked Agents
$(if [ ${#FOUND_LINKS[@]} -eq 0 ]; then echo "None detected."; else printf '%s\n' "${FOUND_LINKS[@]}"; fi)

## Health
$(if [ "$STATUS" == "200" ]; then echo "Healthy ✅"; else echo "Unhealthy ⚠️"; fi)

## Recent Outgoing URLs
$(cat "$DEST/orchestrator_outgoing_urls.txt" | sed 's/^/• /')
EOF

echo "✅ Report ready: $REPORT"
echo "✅ Full environment dump: $DEST/orchestrator_env_raw.txt"
echo "✅ YAML config: $DEST/orchestrator_config.yaml"
echo "============================================================="
echo "Done."
