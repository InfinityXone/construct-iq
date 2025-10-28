#!/bin/bash
set -e
echo "🔐 Bootstrapping Infinity-X One Swarm Secret Sync System..."

ROOT="$HOME/infinity-x-one-swarm"
SYNC_DIR="$ROOT/bootstrap_secret_sync"
mkdir -p "$SYNC_DIR/logs"
mkdir -p "$SYNC_DIR/backups"

PROJECT_ID="infinity-x-one-swarm-system"
BUCKET_NAME="gcs-bucket-artifacts"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$SYNC_DIR/logs/sync_${TIMESTAMP}.log"

echo "📦 Using GCP Project: $PROJECT_ID" | tee -a "$LOG_FILE"
echo "🪣 Backup Bucket: $BUCKET_NAME" | tee -a "$LOG_FILE"

# Backup current GCP secrets to bucket
echo "☁️ Backing up GCP secrets to bucket..." | tee -a "$LOG_FILE"
gcloud secrets list --project="$PROJECT_ID" --format="value(name)" | while read -r SECRET_NAME; do
  echo "📤 Exporting $SECRET_NAME" | tee -a "$LOG_FILE"
  gcloud secrets versions access latest --secret="$SECRET_NAME" --project="$PROJECT_ID" > "$SYNC_DIR/backups/${SECRET_NAME}.txt" 2>/dev/null || true
done
gsutil -m cp "$SYNC_DIR/backups/*" "gs://$BUCKET_NAME/backups/secrets_${TIMESTAMP}/" || true

# Generate schema report
SCHEMA_FILE="$SYNC_DIR/SCHEMA.md"
echo "# Infinity-X One Swarm Secret Schema" > "$SCHEMA_FILE"
echo "_Generated $(date)_" >> "$SCHEMA_FILE"
echo "" >> "$SCHEMA_FILE"
gcloud secrets list --project="$PROJECT_ID" --format="table(name,createTime)" >> "$SCHEMA_FILE"

# Create GitHub + Vercel sync (placeholders for security)
echo "🔁 Syncing with GitHub and Vercel..." | tee -a "$LOG_FILE"
echo "(For security, this version uses placeholders. Replace tokens to enable live sync.)" | tee -a "$LOG_FILE"

# Placeholder GitHub sync (manual token required)
# gh secret set OPENAI_API_KEY --body "$(gcloud secrets versions access latest --secret=OPENAI_API_KEY --project=$PROJECT_ID)"

# Placeholder Vercel sync
# vercel env add OPENAI_API_KEY production "$(gcloud secrets versions access latest --secret=OPENAI_API_KEY --project=$PROJECT_ID)"

# Local .env hydration
echo "🧬 Hydrating local .env" | tee -a "$LOG_FILE"
> "$ROOT/.env"
for SECRET_NAME in $(gcloud secrets list --project="$PROJECT_ID" --format="value(name)"); do
  VALUE=$(gcloud secrets versions access latest --secret="$SECRET_NAME" --project="$PROJECT_ID" 2>/dev/null || echo "")
  if [[ -n "$VALUE" ]]; then
    echo "$SECRET_NAME=\"$VALUE\"" >> "$ROOT/.env"
  fi
done

# Create status report
STATUS_FILE="$SYNC_DIR/SECRET_SYNC_STATUS.md"
echo "# 🔄 Secret Sync Status" > "$STATUS_FILE"
echo "_Last synced: $(date)_" >> "$STATUS_FILE"
echo "" >> "$STATUS_FILE"
ls -lh "$SYNC_DIR/backups" >> "$STATUS_FILE"

echo "✅ Secret sync complete. Logs saved to $LOG_FILE"
echo "📘 Reports generated:"
echo " - $SCHEMA_FILE"
echo " - $STATUS_FILE"
