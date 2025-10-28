#!/bin/bash
# ========================================================
# Verifies the freshness of the latest backup in GCS
# ========================================================

BUCKET="gs://infinity-x-one-swarm-system/backups/"
THRESHOLD_HOURS=24
LOGFILE=~/infinity-x-one-swarm/HEALTH_HISTORY.md

echo "🧠 Checking latest backup in ${BUCKET}..."
LATEST=$(gsutil ls -l "${BUCKET}" | grep -v TOTAL | sort -k2 -r | head -n1)
LATEST_TIME=$(echo "$LATEST" | awk '{print $2}')
LATEST_FILE=$(echo "$LATEST" | awk '{print $3}')

if [ -z "$LATEST_FILE" ]; then
  echo "⚠️  No backups found!"
  echo "$(date -u) - MISSING BACKUP" >> "$LOGFILE"
  exit 1
fi

DIFF_HOURS=$(( ($(date -u +%s) - $(date -u -d "$LATEST_TIME" +%s)) / 3600 ))

if [ "$DIFF_HOURS" -gt "$THRESHOLD_HOURS" ]; then
  echo "⚠️  Backup is stale (${DIFF_HOURS}h old)."
  echo "$(date -u) - STALE BACKUP (${DIFF_HOURS}h old): $LATEST_FILE" >> "$LOGFILE"
else
  echo "✅ Latest backup is fresh (${DIFF_HOURS}h old): $LATEST_FILE"
  echo "$(date -u) - OK (${DIFF_HOURS}h old): $LATEST_FILE" >> "$LOGFILE"
fi
