#!/bin/bash
# =====================================================================
# Infinity-X One Swarm System - Rosetta Memory Gateway Cloud Sync
# Reuses existing Cloud Run + GCS memory bucket
# =====================================================================

set -e
PROJECT="infinity-x-one-swarm-system"
REGION="us-east1"
SERVICE="memory-gateway"  # Existing Cloud Run service name
LOCAL_MANIFEST="$HOME/infinity-x-one-swarm/bootstrap_memory_gateway/HYDRATION_MANIFEST.json"
TMP_UPLOAD_DIR="/tmp/memory_gateway_sync"
DATESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')

echo "🧠 Syncing Infinity-X Rosetta Memory Gateway..."
echo "📦 Project: $PROJECT | Region: $REGION"
echo "📄 Manifest: $LOCAL_MANIFEST"

# 1️⃣ Validate Cloud Run service exists
if ! gcloud run services describe "$SERVICE" --region="$REGION" --project="$PROJECT" &>/dev/null; then
  echo "❌ ERROR: Cloud Run service '$SERVICE' not found in project '$PROJECT'."
  exit 1
fi
echo "✅ Found existing Cloud Run service."

# 2️⃣ Get Cloud Run URL
SERVICE_URL=$(gcloud run services describe "$SERVICE" --region="$REGION" --project="$PROJECT" \
  --format="value(status.url)")
echo "🌐 Cloud Run URL: $SERVICE_URL"

# 3️⃣ Prepare local schema sync files
mkdir -p "$TMP_UPLOAD_DIR"
cp "$LOCAL_MANIFEST" "$TMP_UPLOAD_DIR/"
cp "$HOME/infinity-x-one-swarm/bootstrap_memory_gateway/schemas/firestore_schema.json" "$TMP_UPLOAD_DIR/"
echo "📁 Prepared schema + manifest for upload."

# 4️⃣ Use your existing GCS bucket
BASE_BUCKET="gs://infinity-x-one-swarm-system-memory"
SYNC_PATH="$BASE_BUCKET/memory_gateway_sync"

echo "📤 Syncing schema + manifest to $SYNC_PATH..."
gsutil -m cp -r "$TMP_UPLOAD_DIR/*" "$SYNC_PATH/" || {
  echo "❌ GCS sync failed. Please verify bucket permissions."
  exit 1
}
echo "✅ Synced schema + manifest to $SYNC_PATH"

# 5️⃣ Notify Cloud Run Gateway (optional)
echo "🔔 Sending schema update signal to Cloud Run Gateway..."
curl -s -X POST "$SERVICE_URL/update-schema" \
  -H "Content-Type: application/json" \
  -d @"$LOCAL_MANIFEST" || echo "⚠️ /update-schema endpoint not available — skipped."

# 6️⃣ Log completion
echo "✅ Memory Gateway cloud sync complete at $DATESTAMP"
