#!/bin/bash
set -e
echo "☁️ Cloud Auto-Heal started at $(date)"
PROJECT="infinity-x-one-swarm-system"

# Restart unhealthy Cloud Run revisions
for svc in $(gcloud run services list --project=$PROJECT --format="value(metadata.name)"); do
  echo "🌀 Checking service: $svc"
  STATUS=$(gcloud run services describe $svc --project=$PROJECT --format="value(status.conditions[?type='Ready'].status)")
  if [[ "$STATUS" != "True" ]]; then
    echo "⚠️ $svc unhealthy — redeploying..."
    gcloud run services update $svc --project=$PROJECT --region=us-east1 --quiet || true
  fi
done

# Sync secrets
bash scripts/sync_secrets.sh

echo "✅ Cloud Auto-Heal complete."
