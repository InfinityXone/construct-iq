#!/bin/bash
# ========================================================
# Minimal /backup Implementation for Orchestrator
# Creates a compressed archive and uploads to GCS.
# ========================================================

PROJECT_ID="infinity-x-one-swarm-system"
BUCKET_NAME="infinity-x-one-swarm-system"
SRC_DIR="/home/infinity-x-one/infinity-x-one-swarm"
TMP_FILE="/tmp/infinity-x-one-swarm-$(date -u +"%Y-%m-%dT%H-%M-%SZ").tar.gz"
DEST_DIR="gs://${BUCKET_NAME}/backups/"

echo "🔹 Creating archive..."
tar -czf "$TMP_FILE" "$SRC_DIR" 2>/dev/null || {
  echo "❌ Failed to create archive."
  exit 1
}

echo "🔹 Uploading to GCS..."
gsutil cp "$TMP_FILE" "$DEST_DIR" >/dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "✅ Backup uploaded successfully → ${DEST_DIR}$(basename "$TMP_FILE")"
  echo "$(date -u) SUCCESS: $(basename "$TMP_FILE")" >> ~/infinity-x-one-swarm/BACKUP_HISTORY.log
else
  echo "❌ Upload failed. Check GCS permissions or bucket path."
  echo "$(date -u) FAILED" >> ~/infinity-x-one-swarm/BACKUP_HISTORY.log
fi

rm -f "$TMP_FILE"
