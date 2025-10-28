#!/bin/bash
# =============================================================
# Infinity-X One — Guardian + Self-Heal Watchdog v1.0
# Monitors every agent in .env, logs status, triggers heal
# =============================================================

DEST="$HOME/infinity-x-one-swarm"
ENV_FILE="$DEST/.env"
LOG_FILE="$DEST/GUARDIAN_LOG.md"
HISTORY_FILE="$DEST/HEALTH_HISTORY.md"
MEM_URL=$(grep '^MEMORY_GATEWAY_URL=' "$ENV_FILE" | cut -d'=' -f2)
PROJECT="infinity-x-one-swarm-system"

echo "🛡️  Guardian Watch — $(date)" | tee -a "$LOG_FILE"
echo "=============================================================" | tee -a "$LOG_FILE"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ .env not found. Exiting."
  exit 1
fi

while IFS='=' read -r key value; do
  if [[ "$key" == *"_URL" ]]; then
    svc=${key%_URL}
    echo "🔍 Checking $svc ..." | tee -a "$LOG_FILE"

    status_code=$(curl -s -o /dev/null -w "%{http_code}" "$value/health")
    if [[ "$status_code" == "200" ]]; then
      echo "✅ $svc healthy ($value)" | tee -a "$LOG_FILE"
      echo "| $svc | $value | ✅ Healthy | $(date) |" >> "$HISTORY_FILE"
    else
      echo "⚠️  $svc unhealthy ($status_code) — attempting repair..." | tee -a "$LOG_FILE"
      echo "| $svc | $value | ❌ Unhealthy ($status_code) | $(date) |" >> "$HISTORY_FILE"

      # Attempt to redeploy the service
      gcloud run services update "$svc" \
        --project="$PROJECT" \
        --region=us-east1 \
        --quiet >/dev/null 2>&1

      if [[ $? -eq 0 ]]; then
        echo "🩺 $svc redeployment triggered." | tee -a "$LOG_FILE"
      else
        echo "🚫 $svc redeploy failed — manual check required." | tee -a "$LOG_FILE"
      fi

      # Notify Memory Gateway
      if [[ -n "$MEM_URL" ]]; then
        curl -s -X POST "$MEM_URL/report" \
          -H "Content-Type: application/json" \
          -d "{\"agent\":\"$svc\",\"status\":\"unhealthy\",\"time\":\"$(date)\"}" >/dev/null
      fi
    fi
    echo "-------------------------------------------------------------" | tee -a "$LOG_FILE"
  fi
done < "$ENV_FILE"

echo "🧠 Updating Memory Gateway with global status..." | tee -a "$LOG_FILE"
if [[ -n "$MEM_URL" ]]; then
  curl -s -X POST "$MEM_URL/hydrate" \
    -H "Content-Type: application/json" \
    -d "{\"guardian\":\"complete\",\"timestamp\":\"$(date)\",\"project\":\"$PROJECT\"}" >/dev/null
  echo "✅ Memory updated." | tee -a "$LOG_FILE"
else
  echo "⚠️  Memory URL missing." | tee -a "$LOG_FILE"
fi

echo "============================================================="
echo "📘 Log: $LOG_FILE"
echo "📜 History: $HISTORY_FILE"
echo "✅ Guardian cycle complete."
