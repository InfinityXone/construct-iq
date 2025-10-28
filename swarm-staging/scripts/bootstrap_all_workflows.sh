#!/bin/bash
set -e

echo "🚀 Bootstrapping full Infinity-X Swarm automation suite..."
cd ~/infinity-x-one-swarm

# Ensure directories exist
mkdir -p .github/workflows ci vercel logs

########################################
# 1️⃣  AUTO-OPS (Daily Maintenance)
########################################
cat > .github/workflows/auto_ops.yml <<'YAML'
name: Infinity-X Auto-Ops

on:
  schedule:
    - cron: "0 2 * * *"
  push:
    branches: [main]

jobs:
  maintenance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - name: Run Auto-Ops
        run: |
          chmod +x scripts/production_auto_ops.sh
          ./scripts/production_auto_ops.sh
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
          GROQ_API_KEY: ${{ secrets.GROQ_API_KEY }}
          GOOGLE_PROJECT_ID: infinity-x-one-swarm-system
      - uses: actions/upload-artifact@v4
        with:
          name: auto-ops-logs
          path: logs/
YAML

########################################
# 2️⃣  AUTO-TAG (Version Tagging)
########################################
cat > .github/workflows/auto_tag.yml <<'YAML'
name: Infinity-X Auto-Tag

on:
  push:
    branches: [main]

jobs:
  tagging:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Auto-tag new release
        run: |
          TAG="v$(date +%Y%m%d-%H%M)"
          git tag -a $TAG -m "Automated version tag $TAG"
          git push origin $TAG
YAML

########################################
# 3️⃣  AUTO-HEAL (Self-Fix & Repo Agent)
########################################
cat > .github/workflows/auto_heal.yml <<'YAML'
name: Infinity-X Auto-Heal

on:
  workflow_run:
    workflows: ["Infinity-X Auto-Ops"]
    types:
      - completed

jobs:
  heal:
    if: ${{ github.event.workflow_run.conclusion == 'failure' }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Heal repository
        run: |
          echo "🧠 Detected workflow failure. Initiating repo agent..."
          chmod +x scripts/repo_agent.sh
          ./scripts/repo_agent.sh || echo "⚠️ Repo agent failed gracefully."
      - name: Commit healed changes
        run: |
          git add .
          git commit -m "🩺 Auto-heal fix at $(date)"
          git push origin main || true
YAML

########################################
# 4️⃣  GPT-ACTIONS (Smart Agent Branches)
########################################
cat > .github/workflows/gpt_action.yml <<'YAML'
name: Infinity-X GPT Agent

on:
  workflow_dispatch:
  push:
    branches: [main]

jobs:
  agent:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run GPT-based repo agent
        run: |
          chmod +x scripts/repo_agent.sh
          ./scripts/repo_agent.sh
YAML

########################################
# 5️⃣  VERCEL DEPLOY (Frontend/Dashboard)
########################################
cat > .github/workflows/vercel_deploy.yml <<'YAML'
name: Infinity-X Vercel Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Vercel
        run: |
          npx vercel --prod --token=\${{ secrets.VERCEL_TOKEN }}
YAML

########################################
# 6️⃣  GCP SYNC (Secrets + Cloud Run)
########################################
cat > .github/workflows/gcp_sync.yml <<'YAML'
name: Infinity-X GCP Sync

on:
  schedule:
    - cron: "30 2 * * *"
  push:
    branches: [main]

jobs:
  gcp:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Configure gcloud
        uses: google-github-actions/setup-gcloud@v2
        with:
          project_id: infinity-x-one-swarm-system
          service_account_key: ${{ secrets.GCP_SERVICE_ACCOUNT }}
      - name: Sync Secrets
        run: |
          gcloud secrets versions access latest --secret=OPENAI_API_KEY > secrets/OPENAI_API_KEY.txt
          gcloud secrets versions access latest --secret=GROQ_API_KEY > secrets/GROQ_API_KEY.txt
YAML

########################################
# ✅ Finalize Setup
########################################
git add .github ci vercel
git commit -m "🚀 Add full Infinity-X Swarm CI/CD suite (GitHub + GCP + Vercel)"
git push origin main

echo "✅ All workflows created and pushed successfully!"
echo "🧠 Verify them under: https://github.com/InfinityXone/infinity-x-one-swarm/actions"
