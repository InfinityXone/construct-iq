#!/usr/bin/env bash
set -euo pipefail

echo "=== Construct-IQ Cloud Wizard (GCP) ==="
command -v gcloud >/dev/null || { echo "gcloud CLI not found. Install the Google Cloud SDK."; exit 1; }

# ---------- Login / account ----------
if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q "@"; then
  echo "No active gcloud account. Opening login..."
  gcloud auth login --brief
fi
ACTIVE_ACCT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)')"
echo "Active account: $ACTIVE_ACCT"  # gcloud auth login docs :contentReference[oaicite:1]{index=1}

# ---------- Project ----------
CUR_PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "${PROJECT:-}" ]]; then
  read -rp "Project ID [default: ${CUR_PROJECT:-<none>}]: " PROJECT_INPUT
  PROJECT="${PROJECT_INPUT:-$CUR_PROJECT}"
  [[ -z "$PROJECT" ]] && { echo "Project is required."; exit 1; }
fi
gcloud config set project "$PROJECT" >/dev/null
echo "Project set: $PROJECT"

# ---------- Region ----------
read -rp "Region [default: us-east1]: " REGION
REGION="${REGION:-us-east1}"

# ---------- Enable APIs ----------
echo "Enabling core services (idempotent)…"
gcloud services enable run.googleapis.com artifactregistry.googleapis.com secretmanager.googleapis.com sqladmin.googleapis.com cloudbuild.googleapis.com --quiet

# ---------- Artifact Registry repo ----------
AR_REPO="${AR_REPO:-ciq}"
gcloud artifacts repositories create "$AR_REPO" --repository-format=DOCKER --location="$REGION" --quiet || true
AR_PATH="$REGION-docker.pkg.dev/$PROJECT/$AR_REPO"
echo "Artifact Registry: $AR_PATH"  # Artifact Registry repos :contentReference[oaicite:2]{index=2}

# ---------- Cloud SQL instance selection/creation ----------
echo "Listing Cloud SQL instances in project…"
gcloud sql instances list --format='table(name:label=NAME,region:label=REGION,connectionName:label=CONNECTION)' || true
read -rp "Cloud SQL instance name (existing or new): " SQL_INSTANCE

EXISTS="$(gcloud sql instances list --filter="name=$SQL_INSTANCE" --format='value(name)')"
if [[ -z "$EXISTS" ]]; then
  read -rp "DB version (e.g., POSTGRES_14) [default POSTGRES_14]: " DB_VER
  DB_VER="${DB_VER:-POSTGRES_14}"
  echo "Creating instance $SQL_INSTANCE in $REGION ($DB_VER)…"
  gcloud sql instances create "$SQL_INSTANCE" --database-version="$DB_VER" --region="$REGION" --quiet
fi

# Confirm instance + connection name (INSTANCE_CONNECTION_NAME = project:region:instance)
CONN_NAME="$(gcloud sql instances describe "$SQL_INSTANCE" --format='value(connectionName)')"
echo "SQL connection: $CONN_NAME"  # Cloud Run↔Cloud SQL Unix socket path :contentReference[oaicite:3]{index=3}

# ---------- Database + users ----------
read -rp "Primary database name [default: ciq]: " DB_NAME
DB_NAME="${DB_NAME:-ciq}"
DB_EXISTS="$(gcloud sql databases list --instance "$SQL_INSTANCE" --format='value(name)' | grep -x "$DB_NAME" || true)"
[[ -z "$DB_EXISTS" ]] && gcloud sql databases create "$DB_NAME" --instance "$SQL_INSTANCE" --quiet

# App users
APP_USER="${APP_USER:-ciq_app}"
RO_USER="${RO_USER:-ciq_ro}"

# Create/update passwords (never echo)
read -s -rp "Password for $APP_USER: " APP_PASS; echo
read -s -rp "Password for $RO_USER (read-only): " RO_PASS; echo

# Create users if missing, otherwise update passwords
if ! gcloud sql users list --instance "$SQL_INSTANCE" --format='value(name)' | grep -x "$APP_USER" >/dev/null; then
  gcloud sql users create "$APP_USER" --instance "$SQL_INSTANCE" --password "$APP_PASS"
else
  gcloud sql users set-password "$APP_USER" --instance "$SQL_INSTANCE" --password "$APP_PASS"
fi
if ! gcloud sql users list --instance "$SQL_INSTANCE" --format='value(name)' | grep -x "$RO_USER" >/dev/null; then
  gcloud sql users create "$RO_USER" --instance "$SQL_INSTANCE" --password "$RO_PASS"
else
  gcloud sql users set-password "$RO_USER" --instance "$SQL_INSTANCE" --password "$RO_PASS"
fi
# Managing users/databases via gcloud :contentReference[oaicite:4]{index=4}

# ---------- DATABASE_URL (Unix socket DSN) ----------
DATABASE_URL="postgresql://${APP_USER}:${APP_PASS}@/${DB_NAME}?host=/cloudsql/${CONN_NAME}&sslmode=disable"
echo "DATABASE_URL will use Cloud SQL Unix socket at /cloudsql/${CONN_NAME}"  # socket path format :contentReference[oaicite:5]{index=5}

# ---------- Secret Manager ----------
echo "Seeding secrets (Secret Manager)…"
printf '%s' "$DATABASE_URL" | gcloud secrets create DATABASE_URL --data-file=- --quiet || \
gcloud secrets versions add DATABASE_URL --data-file=<(printf '%s' "$DATABASE_URL") --quiet

CIQ_API_KEY="${CIQ_API_KEY:-$(openssl rand -hex 24)}"
printf '%s' "$CIQ_API_KEY" | gcloud secrets create CIQ_API_KEY --data-file=- --quiet || \
gcloud secrets versions add CIQ_API_KEY --data-file=<(printf '%s' "$CIQ_API_KEY") --quiet

read -rp "Optional GSA_API_KEY (blank to skip): " GSA_API_KEY || true
if [[ -n "${GSA_API_KEY:-}" ]]; then
  printf '%s' "$GSA_API_KEY" | gcloud secrets create GSA_API_KEY --data-file=- --quiet || \
  gcloud secrets versions add GSA_API_KEY --data-file=<(printf '%s' "$GSA_API_KEY") --quiet
fi
# Cloud Run recommends Secret Manager over env literals :contentReference[oaicite:6]{index=6}

# ---------- Cloud Run Service Account ----------
RUN_SA_EMAIL="run-ciq@$PROJECT.iam.gserviceaccount.com"
gcloud iam service-accounts create run-ciq --display-name "Run CIQ SA" --quiet || true
# Minimal roles for this flow
gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$RUN_SA_EMAIL" --role="roles/run.admin" --quiet
gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$RUN_SA_EMAIL" --role="roles/artifactregistry.writer" --quiet
gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$RUN_SA_EMAIL" --role="roles/secretmanager.secretAccessor" --quiet
# Grant SA access to each secret
for S in DATABASE_URL CIQ_API_KEY ${GSA_API_KEY:+GSA_API_KEY}; do
  gcloud secrets add-iam-policy-binding "$S" \
    --member="serviceAccount:$RUN_SA_EMAIL" --role="roles/secretmanager.secretAccessor" --quiet || true
done
# Secret → Cloud Run env mapping is supported natively :contentReference[oaicite:7]{index=7}

# ---------- Generate pre-filled scripts ----------
API_IMAGE="$AR_PATH/api:latest"
HARV_IMAGE="$AR_PATH/harvester:latest"

cat > ciq_open.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
gcloud config set project "$PROJECT" >/dev/null
gcloud services enable run.googleapis.com artifactregistry.googleapis.com secretmanager.googleapis.com sqladmin.googleapis.com cloudbuild.googleapis.com --quiet
gcloud artifacts repositories create "$AR_REPO" --repository-format=DOCKER --location="$REGION" --quiet || true
echo "Open complete."
EOF
chmod +x ciq_open.sh

cat > ciq_launch.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
PROJECT="$PROJECT"; REGION="$REGION"
RUN_SA="$RUN_SA_EMAIL"
CLOUDSQL="$CONN_NAME"
API_IMAGE="$API_IMAGE"
HARV_IMAGE="$HARV_IMAGE"

echo "Build images via Cloud Build…"
gcloud builds submit api --tag "\$API_IMAGE" --quiet
gcloud builds submit services/harvester --tag "\$HARV_IMAGE" --quiet  # Cloud Build submit :contentReference[oaicite:8]{index=8}

echo "Deploy API (public)…"
gcloud run deploy api \\
  --image "\$API_IMAGE" \\
  --region "\$REGION" \\
  --allow-unauthenticated \\
  --service-account "\$RUN_SA" \\
  --add-cloudsql-instances "\$CLOUDSQL" \\
  --set-env-vars HEALTH_CHECK_DB=1 \\
  --set-secrets DATABASE_URL=DATABASE_URL:latest,CIQ_API_KEY=CIQ_API_KEY:latest --quiet

API_URL="\$(gcloud run services describe api --region "\$REGION" --format='value(status.url)')"

echo "Deploy Harvester (private)…"
gcloud run deploy harvester \\
  --image "\$HARV_IMAGE" \\
  --region "\$REGION" \\
  --no-allow-unauthenticated \\
  --service-account "\$RUN_SA" \\
  --add-cloudsql-instances "\$CLOUDSQL" \\
  --set-env-vars HEALTH_CHECK_DB=1 \\
  --set-secrets DATABASE_URL=DATABASE_URL:latest,CIQ_API_KEY=CIQ_API_KEY:latest --quiet

HARV_URL="\$(gcloud run services describe harvester --region "\$REGION" --format='value(status.url)')"

echo "Verify API /health (public)…"
curl -fsS "\$API_URL/health" | jq . || { echo "API health failed"; exit 1; }

echo "Verify Harvester /health (private via ID token)…"
IDT="\$(gcloud auth print-identity-token --audiences="\$HARV_URL")"
curl -fsS -H "Authorization: Bearer \$IDT" "\$HARV_URL/health" | jq . || { echo "Harvester health failed"; exit 1; }
echo "All green."
echo "API: \$API_URL"
echo "Harvester: \$HARV_URL"
EOF
chmod +x ciq_launch.sh

# ---------- Output summary ----------
echo
echo "== SUMMARY =="
echo "Account:  $ACTIVE_ACCT"
echo "Project:  $PROJECT"
echo "Region:   $REGION"
echo "SQL inst: $SQL_INSTANCE"
echo "Conn:     $CONN_NAME"
echo "DB:       $DB_NAME"
echo "Users:    $APP_USER (app), $RO_USER (ro)"
echo
echo "Generated: ./ciq_open.sh and ./ciq_launch.sh"
echo "Run:       ./ciq_open.sh && ./ciq_launch.sh"
