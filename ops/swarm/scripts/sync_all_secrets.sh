#!/usr/bin/env bash
# === Infinity-X Swarm: Global Secret Synchronizer ===
# Sync secrets between Google Secret Manager, GitHub, Vercel, and local .env

set -euo pipefail

# === CONFIGURATION ===
GCP_PROJECT="alpha-omega-deployer"   # Your GCP project name
GITHUB_REPO="InfinityXone/infinity-x-one-swarm"
VERCEL_PROJECT_ID="your-vercel-project-id"  # Fill this in once
LOCAL_ENV_FILE="$HOME/infinity-x-one-swarm/.env"

echo "🔍 Fetching secrets from GCP: $GCP_PROJECT"
SECRETS=$(gcloud secrets list --project "$GCP_PROJECT" --format="value(name)")

if [ -z "$SECRETS" ]; then
  echo "⚠️  No secrets found in GCP project '$GCP_PROJECT'"
  exit 1
fi

echo "✅ Found $(echo "$SECRETS" | wc -l) secrets."

# Ensure required CLI tools exist
for cmd in gcloud gh vercel; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Missing dependency: $cmd"
    exit 1
  fi
done

# === MAIN LOOP ===
for SECRET in $SECRETS; do
  echo "🔐 Syncing secret: $SECRET"

  VALUE=$(gcloud secrets versions access latest \
          --secret="$SECRET" \
          --project="$GCP_PROJECT" 2>/dev/null || echo "")

  if [ -z "$VALUE" ]; then
    echo "⚠️  Secret '$SECRET' has no value, skipping..."
    continue
  fi

  # --- GitHub Sync ---
  echo "➡️  Updating GitHub secret: $SECRET"
  echo -n "$VALUE" | gh secret set "$SECRET" --repo "$GITHUB_REPO" --body -

  # --- Vercel Sync ---
  if [ -n "$VERCEL_PROJECT_ID" ]; then
    echo "➡️  Updating Vercel secret: $SECRET"
    vercel env rm "$SECRET" --yes --project "$VERCEL_PROJECT_ID" >/dev/null 2>&1 || true
    echo -n "$VALUE" | vercel env add "$SECRET" production --project "$VERCEL_PROJECT_ID" >/dev/null
  fi

  # --- Local Sync ---
  echo "➡️  Writing to local .env"
  grep -v "^$SECRET=" "$LOCAL_ENV_FILE" 2>/dev/null > "$LOCAL_ENV_FILE.tmp" || true
  echo "$SECRET=$VALUE" >> "$LOCAL_ENV_FILE.tmp"
  mv "$LOCAL_ENV_FILE.tmp" "$LOCAL_ENV_FILE"
done

echo "🧠 All secrets synced successfully!"
