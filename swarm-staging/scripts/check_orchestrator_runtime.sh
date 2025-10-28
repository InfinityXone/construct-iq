#!/bin/bash
# ========================================================
# Infinity X One - Runtime Detector for Orchestrator
# Detects what language/runtime your Cloud Run service uses
# ========================================================

SERVICE="orchestrator"
REGION="us-east1"
PROJECT="infinity-x-one-swarm-system"

echo "🔍 Checking Cloud Run service: ${SERVICE} (${REGION})..."

# 1️⃣ Get service description (to see image + env vars)
gcloud run services describe $SERVICE \
  --region=$REGION \
  --project=$PROJECT \
  --format="value(spec.template.spec.containers[0].image)"

echo "--------------------------------------------------"
echo "🧠 Checking for Node.js indicators..."

# 2️⃣ Check local deployment structure if mounted
if [ -d "/workspace" ]; then
  if [ -f "/workspace/package.json" ]; then
    echo "✅ Detected Node.js project via package.json in /workspace"
  elif [ -f "./package.json" ]; then
    echo "✅ Detected Node.js project via package.json in current dir"
  elif [ -f "/workspace/server.js" ] || [ -f "/workspace/app.js" ]; then
    echo "✅ Detected Node.js entry point (server.js/app.js)"
  elif [ -f "server.js" ] || [ -f "app.js" ]; then
    echo "✅ Detected Node.js entry point in current directory"
  else
    echo "⚠️ No Node.js indicators found locally."
  fi
else
  echo "ℹ️ No /workspace directory — checking container info only."
fi

echo "--------------------------------------------------"
echo "💡 Tip: If image output includes 'node' (e.g. gcr.io/...:node-18), it's Node.js-based."
echo "--------------------------------------------------"
