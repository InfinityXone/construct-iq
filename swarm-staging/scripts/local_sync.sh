#!/bin/bash
set -e
cd ~/infinity-x-one-swarm
echo "🔁 Syncing local repo with GitHub..."
git pull --rebase origin main
echo "🔐 Syncing secrets from Google..."
gcloud secrets versions access latest --secret=OPENAI_API_KEY --project=infinity-x-one-swarm-system > secrets/OPENAI_API_KEY.txt
gcloud secrets versions access latest --secret=GROQ_API_KEY --project=infinity-x-one-swarm-system > secrets/GROQ_API_KEY.txt
echo "✅ Local environment synced."
