#!/bin/bash
# ==========================================
# 💾 Infinity-X One — Memory Dehydration Script
# ☁️ Enhanced with Cloud Sync + Checksum + Retention
# ==========================================

GATEWAY_URL=http://localhost:8090/memory/dump
SNAPSHOT_FILE=~/infinity-x-one-swarm/memory-gateway/state_snapshot.json
BACKUP_BUCKET=gs://infinity-x-one-swarm-system/backups
TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
BACKUP_FILE="infinity-x-one-swarm-$TIMESTAMP.tar.gz"
TMP_ARCHIVE=/tmp/$BACKUP_FILE
MANIFEST=~/infinity-x-one-swarm/memory-gateway/backup_manifest.json

echo "💾 Dumping current memory state..."
curl -s -X GET "$GATEWAY_URL" -H "Accept: application/json" -o "$SNAPSHOT_FILE"

if [ ! -s "$SNAPSHOT_FILE" ]; then
  echo "❌ Failed to save memory snapshot."
  exit 1
fi

echo "✅ Memory snapshot saved → $SNAPSHOT_FILE"
echo "🔹 Creating compressed archive..."
tar -czf "$TMP_ARCHIVE" -C "$(dirname "$SNAPSHOT_FILE")" "$(basename "$SNAPSHOT_FILE")"

# Compute checksum
CHECKSUM=$(sha256sum "$TMP_ARCHIVE" | awk '{print $1}')
SIZE=$(du -h "$TMP_ARCHIVE" | awk '{print $1}')

echo "🔹 Uploading to Google Cloud Storage..."
if gsutil cp "$TMP_ARCHIVE" "$BACKUP_BUCKET/$BACKUP_FILE" >/dev/null 2>&1; then
  echo "✅ Backup uploaded successfully → $BACKUP_BUCKET/$BACKUP_FILE"
else
  echo "⚠️  Cloud upload failed — check gsutil authentication or network."
  rm -f "$TMP_ARCHIVE"
  exit 2
fi

# Verify checksum in GCS
echo "🔹 Verifying uploaded file integrity..."
REMOTE_HASH=$(gsutil hash -h "$BACKUP_BUCKET/$BACKUP_FILE" | grep "Hash (sha256):" | awk '{print $3}')

if [[ "$CHECKSUM" == "$REMOTE_HASH" ]]; then
  echo "✅ Checksum verification passed."
else
  echo "⚠️  Checksum mismatch! Local: $CHECKSUM, Remote: $REMOTE_HASH"
fi

# Update manifest
echo "🔹 Updating manifest log..."
mkdir -p "$(dirname "$MANIFEST")"
jq -n --arg time "$TIMESTAMP" \
      --arg file "$BACKUP_FILE" \
      --arg size "$SIZE" \
      --arg checksum "$CHECKSUM" \
      --arg bucket "$BACKUP_BUCKET" \
      '{
        timestamp: $time,
        file: $file,
        size: $size,
        checksum: $checksum,
        bucket: $bucket
      }' > /tmp/new_entry.json

if [ -f "$MANIFEST" ]; then
  jq ". + [$(cat /tmp/new_entry.json)]" "$MANIFEST" > /tmp/tmp_manifest.json
  mv /tmp/tmp_manifest.json "$MANIFEST"
else
  jq -n "[$(cat /tmp/new_entry.json)]" > "$MANIFEST"
fi
rm -f /tmp/new_entry.json

# Retention policy: keep last 10 backups
echo "🔹 Applying retention policy (keep last 10)..."
BACKUPS_TO_DELETE=$(gsutil ls "$BACKUP_BUCKET/" | sort | head -n -10)
if [ -n "$BACKUPS_TO_DELETE" ]; then
  echo "$BACKUPS_TO_DELETE" | xargs -r gsutil rm
  echo "🧹 Old backups pruned."
else
  echo "✅ Less than 10 backups — nothing to delete."
fi

rm -f "$TMP_ARCHIVE"
echo "✅ Dehydration and cloud sync complete."
