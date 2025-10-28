#!/bin/bash
set -e

echo "🧠 [$(date)] Starting Infinity-X One repo purge & sync..."

REPO_DIR="$HOME/infinity-x-one-swarm"
cd "$REPO_DIR"

# 🧹 Clean transient build and GCS artifacts
echo "🧹 Removing cached build artifacts..."
find "$REPO_DIR/gcs" -type f \( -name "*.tgz" -o -name "*.zip" \) -delete 2>/dev/null || true
find "$REPO_DIR" -type f -name "*.log" -delete 2>/dev/null || true
find "$REPO_DIR" -type f -name "*.tmp" -delete 2>/dev/null || true

# 🪣 Prune empty directories
find "$REPO_DIR/gcs" -type d -empty -delete 2>/dev/null || true

# 🧭 Verify health of core systems before sync
bash "$REPO_DIR/scripts/self_heal_and_sync.sh" || true

# 🌐 ngrok auto connection check
if ! pgrep -x "ngrok" >/dev/null; then
  echo "🚀 Launching ngrok tunnel..."
  nohup ngrok http 8080 > /dev/null 2>&1 &
  sleep 5
  echo "✅ ngrok tunnel re-established."
fi

# ☁️ Infinity Cloud + Memory Gateway sync
echo "☁️ Syncing with Infinity Cloud and Memory Gateway..."
gcloud config configurations activate infinity-x-one 2>/dev/null || true
gcloud auth activate-service-account --key-file="$HOME/infinity-x-one-swarm/config/cloud-key.json" 2>/dev/null || true
gsutil rsync -r "$REPO_DIR/memory-gateway" gs://infinity-x-one-memory-backup 2>/dev/null || true

# 🧬 Infinity Agent sync
echo "🔗 Linking with Infinity Agent..."
curl -s -X POST https://infinity-agent-938446344277.us-east1.run.app/sync \
  -H "Content-Type: application/json" \
  -d '{"agent":"infinity-x-one","mode":"autonomous"}' >/dev/null 2>&1 || true

# 🪶 Commit + push
echo "📦 Committing changes..."
git add -A
git commit -m "🧩 Auto-clean and sync at $(date)" || echo "⚠️ No new changes to commit"
git push origin main || echo "⚠️ Push skipped or failed, check connection."

echo "✅ [$(date)] Autonomous repo purge & sync complete."
