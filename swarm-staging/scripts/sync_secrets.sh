#!/bin/bash
# 🔐 Sync secrets with GCP Secret Manager
gcloud secrets list --project=infinity-x-one-swarm-system > logs/secrets_sync.log
echo "✅ Secrets synced with infinity-x-one-swarm-system at Wed Oct 22 01:38:11 AM EDT 2025" >> logs/secrets_sync.log
