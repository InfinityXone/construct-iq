#!/bin/bash
# ===============================================================
# ☁️ Infinity-X One — Google Cloud Project Audit & Health Check
# ===============================================================
# Audits Cloud Run services, service accounts, endpoints, and status.
# Outputs a markdown summary of the entire Infinity-X One system.
# Requires: gcloud CLI configured and authorized for the project.

PROJECT_ID="infinity-x-one-swarm-system"
REGION="us-east1"
DATE=$(date "+%Y-%m-%d %H:%M:%S")
REPORT="$HOME/infinity-x-one-swarm/GCP_PROJECT_STATUS_SUMMARY.md"
LOG="$HOME/infinity-x-one-swarm/GCP_PROJECT_STATUS_LOG.txt"

echo "🧭 Checking GCP Project: $PROJECT_ID"
echo "📅 Timestamp: $DATE"
echo "=============================================================" | tee "$LOG"

# --- 1️⃣ Verify gcloud configuration ---
echo "🔹 Verifying gcloud authentication..." | tee -a "$LOG"
ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
if [ -z "$ACTIVE_ACCOUNT" ]; then
  echo "❌ No active gcloud account found. Please run 'gcloud auth login'." | tee -a "$LOG"
  exit 1
fi
echo "✅ Authenticated as: $ACTIVE_ACCOUNT" | tee -a "$LOG"

# --- 2️⃣ Get Cloud Run services ---
echo "🚀 Fetching Cloud Run services..." | tee -a "$LOG"
SERVICES=$(gcloud run services list --project="$PROJECT_ID" --region="$REGION" --format="value(metadata.name)" 2>/dev/null)

if [ -z "$SERVICES" ]; then
  echo "⚠️ No Cloud Run services found in region $REGION." | tee -a "$LOG"
else
  for svc in $SERVICES; do
    echo "-------------------------------------------------------------" | tee -a "$LOG"
    echo "🔹 Service: $svc" | tee -a "$LOG"

    CREATED=$(gcloud run services describe "$svc" --project="$PROJECT_ID" --region="$REGION" --format="value(metadata.creationTimestamp)" 2>/dev/null)
    URL=$(gcloud run services describe "$svc" --project="$PROJECT_ID" --region="$REGION" --format="value(status.url)" 2>/dev/null)
    STATUS=$(gcloud run services describe "$svc" --project="$PROJECT_ID" --region="$REGION" --format="value(status.conditions[0].status)" 2>/dev/null)
    UPDATED=$(gcloud run services describe "$svc" --project="$PROJECT_ID" --region="$REGION" --format="value(status.latestReadyRevisionName)" 2>/dev/null)
    IMAGE=$(gcloud run services describe "$svc" --project="$PROJECT_ID" --region="$REGION" --format="value(spec.template.spec.containers[0].image)" 2>/dev/null)

    echo "🗓️  Created: $CREATED" | tee -a "$LOG"
    echo "📦  Image: $IMAGE" | tee -a "$LOG"
    echo "🌐  Endpoint: $URL" | tee -a "$LOG"
    echo "⚙️  Latest Revision: $UPDATED" | tee -a "$LOG"
    echo "💚  Health: $STATUS" | tee -a "$LOG"
  done
fi

# --- 3️⃣ Check Service Accounts ---
echo "👥 Checking Service Accounts..." | tee -a "$LOG"
SVC_ACCOUNTS=$(gcloud iam service-accounts list --project="$PROJECT_ID" --format="table(name,email,disabled)" 2>/dev/null)
echo "$SVC_ACCOUNTS" | tee -a "$LOG"

# --- 4️⃣ List Storage Buckets ---
echo "🪣 Checking Cloud Storage buckets..." | tee -a "$LOG"
BUCKETS=$(gcloud storage buckets list --project="$PROJECT_ID" --format="table(name,location,metageneration,updateTime)" 2>/dev/null)
echo "$BUCKETS" | tee -a "$LOG"

# --- 5️⃣ Summarize into Markdown Report ---
{
  echo "# ☁️ Infinity-X One — GCP Project Status Summary"
  echo "### Timestamp: $DATE"
  echo "### Project ID: $PROJECT_ID"
  echo ""
  echo "## 🚀 Cloud Run Services"
  if [ -z "$SERVICES" ]; then
    echo "- None found."
  else
    for svc in $SERVICES; do
      CREATED=$(gcloud run services describe "$svc" --project="$PROJECT_ID" --region="$REGION" --format="value(metadata.creationTimestamp)" 2>/dev/null)
      URL=$(gcloud run services describe "$svc" --project="$PROJECT_ID" --region="$REGION" --format="value(status.url)" 2>/dev/null)
      STATUS=$(gcloud run services describe "$svc" --project="$PROJECT_ID" --region="$REGION" --format="value(status.conditions[0].status)" 2>/dev/null)
      IMAGE=$(gcloud run services describe "$svc" --project="$PROJECT_ID" --region="$REGION" --format="value(spec.template.spec.containers[0].image)" 2>/dev/null)
      echo "- **$svc**"
      echo "  - Created: $CREATED"
      echo "  - Status: $STATUS"
      echo "  - Endpoint: [$URL]($URL)"
      echo "  - Image: \`$IMAGE\`"
      echo ""
    done
  fi
  echo ""
  echo "## 👥 Service Accounts"
  gcloud iam service-accounts list --project="$PROJECT_ID" --format="table(displayName,email,disabled)"
  echo ""
  echo "## 🪣 Storage Buckets"
  gcloud storage buckets list --project="$PROJECT_ID" --format="table(name,location,metageneration,updateTime)"
  echo ""
} > "$REPORT"

echo "✅ GCP audit complete."
echo "📘 Summary written to: $REPORT"
echo "🪵 Full log: $LOG"
