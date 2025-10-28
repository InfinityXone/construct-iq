#!/bin/bash
# ===============================================================
# ☁️ Infinity-X One — Focused Cloud Run + Bucket Summary (Oct 20–22 2025)
# ===============================================================

PROJECT_ID="infinity-x-one-swarm-system"
REGION="us-east1"
REPORT="$HOME/infinity-x-one-swarm/GCP_RECENT_RUNS_SUMMARY.md"

START_DATE="2025-10-20T00:00:00Z"
END_DATE="2025-10-23T00:00:00Z"
START_EPOCH=$(date -d "$START_DATE" +%s)
END_EPOCH=$(date -d "$END_DATE" +%s)

echo "🧭 Collecting Cloud Run deployments between $START_DATE and $END_DATE"
echo "=============================================================="

echo "# ☁️ Infinity-X One — Recent Deployments (Oct 20–22 2025)" > "$REPORT"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT"
echo "Project: $PROJECT_ID" >> "$REPORT"
echo "" >> "$REPORT"

# --- 1️⃣  Get all services and filter by creation timestamp
SERVICES=$(gcloud run services list --project="$PROJECT_ID" --region="$REGION" --format="value(metadata.name)")

for svc in $SERVICES; do
  CREATED=$(gcloud run services describe "$svc" --project="$PROJECT_ID" --region="$REGION" \
             --format="value(metadata.creationTimestamp)")
  CREATED_EPOCH=$(date -d "$CREATED" +%s 2>/dev/null || echo 0)

  if (( CREATED_EPOCH >= START_EPOCH && CREATED_EPOCH <= END_EPOCH )); then
    URL=$(gcloud run services describe "$svc" --project="$PROJECT_ID" --region="$REGION" --format="value(status.url)")
    IMAGE=$(gcloud run services describe "$svc" --project="$PROJECT_ID" --region="$REGION" --format="value(spec.template.spec.containers[0].image)")
    STATUS=$(gcloud run services describe "$svc" --project="$PROJECT_ID" --region="$REGION" --format="value(status.conditions[0].status)")
    REV=$(gcloud run services describe "$svc" --project="$PROJECT_ID" --region="$REGION" --format="value(status.latestReadyRevisionName)")

    echo "## 🚀 $svc" >> "$REPORT"
    echo "- Created: $CREATED" >> "$REPORT"
    echo "- Health: $STATUS" >> "$REPORT"
    echo "- Revision: $REV" >> "$REPORT"
    echo "- Image: \`$IMAGE\`" >> "$REPORT"
    echo "- Endpoint: [$URL]($URL)" >> "$REPORT"
    echo "" >> "$REPORT"
  fi
done

# --- 2️⃣  Append .env if it exists
if [ -f "$HOME/infinity-x-one-swarm/.env" ]; then
  echo "## 🔐 Environment (.env)" >> "$REPORT"
  grep -v '^#' "$HOME/infinity-x-one-swarm/.env" | sed '/^$/d' >> "$REPORT"
  echo "" >> "$REPORT"
fi

# --- 3️⃣  Buckets containing "infinity-x-one-swarm-system"
echo "## 🪣 Buckets (Project: $PROJECT_ID)" >> "$REPORT"
for b in $(gcloud storage buckets list --project="$PROJECT_ID" --format="value(name)" | grep "infinity-x-one-swarm-system"); do
  echo "### Bucket: $b" >> "$REPORT"
  gcloud storage buckets describe "$b" --project="$PROJECT_ID" \
      --format="yaml(location,storageClass,updateTime)" >> "$REPORT"
  echo "" >> "$REPORT"
done

echo "✅ Report saved to $REPORT"
