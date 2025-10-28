#!/bin/bash
# 🧠 Repo Agent: maintains repo hygiene, tags, and locks
set -e
cd "$(dirname "$0")/.."
git add .
TIMESTAMP=$(date +%Y%m%d-%H%M)
TAG="v$TIMESTAMP"
echo "🔐 Auto-committing and tagging as $TAG"
git commit -m "Auto-maintenance commit ($TAG)" || true
git tag -a "$TAG" -m "Auto tag by Repo Agent"
git push origin main --tags
