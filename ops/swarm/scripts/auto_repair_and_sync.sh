#!/bin/bash
# =============================================================
# Infinity-X One — Auto Repair + Sync Script
# Author: Infinity-X System
# Updated: $(date)
# =============================================================

PROJECT="infinity-x-one-swarm-system"
REGION="us-east1"
LOGFILE="$HOME/infinity-x-one-swarm/repair_log.md"
STATUSFILE="$HOME/infinity-x-one-swarm/SYSTEM_STATUS.md"

echo "=============================================================" | tee -a $LOGFILE
echo "🛠️  Infinity-X One Auto-Repair + Sync — $(date)" | tee -a $LOGFILE
echo "Project: $PROJECT  |  Region: $REGION" | tee -a $LOGFILE
echo "=============================================================" | tee -a $LOGFILE

# Step 1 — Fetch service list
echo "🔍 Fetching Cloud Run service statuses..." | tee -a $LOGFILE
SERVICES=$(gcloud run services list --project=$PROJECT --region=$REGION --format="value(metadata.name)")

# Step 2 — Cleanup old revisions to free CPU quota
echo "🧹 Cleaning old revisions..." | tee -a $LOGFILE
for svc in $SERVICES; do
  echo "   • $svc — cleaning old revisions" | tee -a $LOGFILE
  gcloud run revisions list --project=$PROJECT --region=$REGION --service=$svc --format="value(metadata.name)" | tail -n +3 | while read rev; do
    gcloud run revisions delete $rev --project=$PROJECT --region=$REGION --quiet
  done
done

# Step 3 — Auto-heal unhealthy services
echo "🩺 Scanning for unhealthy services..." | tee -a $LOGFILE
gcloud run services list --project=$PROJECT --region=$REGION --format="table(metadata.name,status.conditions.status)" > /tmp/services_status.txt

while read line; do
  svc=$(echo $line | awk '{print $1}')
  if [[ "$line" == *"False"* ]] || [[ "$line" == *"Unknown"* ]]; then
    echo "⚠️  Repairing $svc (unhealthy)" | tee -a $LOGFILE
    IMAGE=$(gcloud run services describe $svc --project=$PROJECT --region=$REGION --format="value(spec.template.spec.containers[0].image)")
    if [ -n "$IMAGE" ]; then
      echo "   → Redeploying from image: $IMAGE" | tee -a $LOGFILE
      gcloud run deploy $svc \
        --project=$PROJECT --region=$REGION \
        --image=$IMAGE \
        --cpu=0.25 --memory=256Mi --concurrency=1 --max-instances=1 \
        --timeout=300 --no-traffic --quiet
    else
      echo "   🚫 No valid image found for $svc — skipping" | tee -a $LOGFILE
    fi
  else
    echo "✅ $svc healthy — no action needed" | tee -a $LOGFILE
  fi
done < <(tail -n +2 /tmp/services_status.txt)

# Step 4 — Resync Orchestrator links
echo "🔗 Syncing Orchestrator links..." | tee -a $LOGFILE
ORCH_URL=$(gcloud run services describe orchestrator --project=$PROJECT --region=$REGION --format="value(status.url)")
for svc in $SERVICES; do
  echo "   → Registering $svc with Orchestrator" | tee -a $LOGFILE
  curl -s -X POST "$ORCH_URL/register" -H "Content-Type: application/json" \
       -d "{\"service\":\"$svc\"}" >> $LOGFILE
done

# Step 5 — Update Memory Gateway
echo "🧠 Syncing Memory Gateway with live state..." | tee -a $LOGFILE
MEMORY_URL=$(gcloud run services describe memory-gateway --project=$PROJECT --region=$REGION --format="value(status.url)")
curl -s -X POST "$MEMORY_URL/update_system_state" -H "Content-Type: application/json" \
     -d "{\"timestamp\":\"$(date)\",\"status\":\"synced\"}" >> $LOGFILE

# Step 6 — Update system status file
echo "🧩 Regenerating system blueprint..." | tee -a $LOGFILE
bash ~/infinity-x-one-swarm/scripts/generate_system_blueprint.sh >> $LOGFILE 2>&1
cp ~/infinity-x-one-swarm/SYSTEM_BLUEPRINT.md $STATUSFILE

echo "=============================================================" | tee -a $LOGFILE
echo "✅ Auto-Repair Complete — $(date)" | tee -a $LOGFILE
echo "📜 Log saved to: $LOGFILE" | tee -a $LOGFILE
echo "📘 Status updated: $STATUSFILE" | tee -a $LOGFILE
echo "=============================================================" | tee -a $LOGFILE

