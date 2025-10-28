#!/usr/bin/env bash
# === Infinity-X Schema Sync ===
# Sync local schema folder with Google Cloud Storage and CloudSQL

set -e
PROJECT_ID="infinity-x-one-swarm-system"
BUCKET="gs://$PROJECT_ID-schema"
SCHEMA_DIR="$HOME/infinity-x-one-swarm/schema"
STATUS_FILE="$HOME/infinity-x-one-swarm/docs/SCHEMA_STATUS.md"

echo "🚀 Starting Schema Sync for $PROJECT_ID..."
date > "$STATUS_FILE"

echo "📤 Uploading local schema to $BUCKET..."
gsutil -m rsync -r "$SCHEMA_DIR" "$BUCKET"

echo "🔍 Validating CloudSQL schema..."
# Example placeholder – replace with your SQL Instance name and credentials
gcloud sql databases list --project "$PROJECT_ID" >> "$STATUS_FILE" 2>&1 || true

echo "✅ Schema sync completed at $(date)" >> "$STATUS_FILE"
git add "$STATUS_FILE"
git commit -m "🧠 Schema sync update $(date +%F)"
git push || true
