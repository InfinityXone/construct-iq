#!/bin/bash
# Sync ALL GCP secrets into GitHub Actions vault

set -euo pipefail

GCP_PROJECT="infinity-x-one-swarm-system"
GITHUB_REPO="InfinityXone/construct-iq"

echo "🔐 Fetching full secret list from $GCP_PROJECT..."

SECRET_NAMES=$(gcloud secrets list \
  --project="$GCP_PROJECT" \
  --format="value(name)")

for SECRET_NAME in $SECRET_NAMES; do
  echo "⏳ Fetching $SECRET_NAME from GCP..."
  VALUE=$(gcloud secrets versions access latest \
          --secret="$SECRET_NAME" \
          --project="$GCP_PROJECT" || echo "")

  if [ -z "$VALUE" ]; then
    echo "⚠️  Skipping $SECRET_NAME (empty or unreadable)"
    continue
  fi

  echo "➡️  Setting $SECRET_NAME in GitHub..."
  echo "$VALUE" | gh secret set "$SECRET_NAME" \
    --repo="$GITHUB_REPO" \
    --app=actions
done

echo "✅ All available secrets synced."
