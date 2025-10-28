#!/bin/bash
set -e
echo "🩺 Repo Auto-Heal started at $(date)"
cd "$(dirname "$0")/.."

# Ensure repo health
git fetch --all
git reset --hard origin/main
git clean -fd

# Fix permissions
chmod -R 755 scripts
chmod -R 644 .github/workflows || true

# Run lint & tree repair
bash scripts/auto_tree.sh || true

git add .
git commit -m "🧩 Repo auto-heal $(date)" || true
git push origin main || true

echo "✅ Repo Auto-Heal complete."
