#!/bin/bash
# ===============================================================
# 🚀 Infinity-X One — Show Recent Cloud Run Updates
# ===============================================================
# Lists all Cloud Run services in your project, sorted by last update time.
# Works for any project; no date math — just shows most recent first.

PROJECT_ID="infinity-x-one-swarm-system"
REGION="us-east1"

echo "🧭 Showing most recently updated Cloud Run services for project: $PROJECT_ID"
echo "📅 Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================================="

# List all services and sort by update time descending
gcloud run services list \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="table(metadata.name,metadata.creationTimestamp,status.latestReadyRevisionName,status.conditions[0].status,status.url)" \
  | sort -r -k2

echo "=============================================================="
echo "✅ Done."
