#!/usr/bin/env bash
set -euo pipefail

### --- EDIT THESE IF NEEDED ---
PROJECT="${PROJECT:-infinity-x-one-swarm-system}"
REGION="${REGION:-us-east1}"
SQL_INSTANCE="${SQL_INSTANCE:-ciq-postgres}"   # existing instance
AR_REPO="${AR_REPO:-ciq}"
SA="${SA:-run-ciq@$PROJECT.iam.gserviceaccount.com}"
API_DIR="${API_DIR:-api}"
HARV_DIR="${HARV_DIR:-services/harvester}"
API_REQ="${API_REQ:-$API_DIR/requirements.txt}"
HARV_REQ="${HARV_REQ:-$HARV_DIR/requirements.txt}"
API_IMAGE="$REGION-docker.pkg.dev/$PROJECT/$AR_REPO/api:latest"
HARV_IMAGE="$REGION-docker.pkg.dev/$PROJECT/$AR_REPO/harvester:latest"
CLOUDSQL="$PROJECT:$REGION:$SQL_INSTANCE"

echo "==> Using project: $PROJECT | region: $REGION | sql: $CLOUDSQL"

echo "==> Ensuring services & repo exist (idempotent)…"
gcloud config set project "$PROJECT" >/dev/null
gcloud services enable run.googleapis.com artifactregistry.googleapis.com secretmanager.googleapis.com sqladmin.googleapis.com cloudbuild.googleapis.com --quiet
gcloud artifacts repositories create "$AR_REPO" --repository-format=DOCKER --location="$REGION" --quiet || true

echo "==> Grant SA minimal roles (idempotent)…"
gcloud iam service-accounts create run-ciq --display-name "Run CIQ SA" --quiet || true
gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$SA" --role="roles/run.admin" --quiet
gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$SA" --role="roles/artifactregistry.writer" --quiet
gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$SA" --role="roles/secretmanager.secretAccessor" --quiet
gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$SA" --role="roles/cloudsql.client" --quiet

echo "==> Scaffolding Dockerfiles + requirements if missing…"
mkdir -p "$API_DIR" "$HARV_DIR"

# API requirements + Dockerfile
if [ ! -f "$API_REQ" ]; then
  cat > "$API_REQ" <<'REQ'
fastapi==0.115.0
uvicorn==0.30.0
psycopg[binary]==3.1.19
REQ
fi

if [ ! -f "$API_DIR/Dockerfile" ]; then
  cat > "$API_DIR/Dockerfile" <<'DOCKER'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
ENV PORT=8080
CMD ["uvicorn","api.app.main:app","--host","0.0.0.0","--port","8080"]
DOCKER
fi

# Harvester requirements + Dockerfile
if [ ! -f "$HARV_REQ" ]; then
  cat > "$HARV_REQ" <<'REQ'
psycopg[binary]==3.1.19
requests==2.32.3
REQ
fi

if [ ! -f "$HARV_DIR/Dockerfile" ]; then
  cat > "$HARV_DIR/Dockerfile" <<'DOCKER'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
# If your harvester doesn't expose HTTP, that's fine; keep /health minimal in the code if you want checks.
CMD ["python","-u","ingest_calc.py"]
DOCKER
fi

echo "==> Building images with Cloud Build (Dockerfile must be in these dirs)…"
# Cloud Build builds from the directory that CONTAINS the Dockerfile when using --tag. :contentReference[oaicite:4]{index=4}
gcloud builds submit "$API_DIR" --tag "$API_IMAGE" --quiet
gcloud builds submit "$HARV_DIR" --tag "$HARV_IMAGE" --quiet

echo "==> Deploy API (public) from Artifact Registry image…"
# Deploy container image to Cloud Run (creates a new revision). :contentReference[oaicite:5]{index=5}
gcloud run deploy api \
  --image "$API_IMAGE" \
  --region "$REGION" \
  --allow-unauthenticated \
  --service-account "$SA" \
  --add-cloudsql-instances "$CLOUDSQL" \
  --set-env-vars HEALTH_CHECK_DB=1 \
  --set-secrets DATABASE_URL=DATABASE_URL:latest,CIQ_API_KEY=CIQ_API_KEY:latest \
  --quiet

API_URL="$(gcloud run services describe api --region "$REGION" --format='value(status.url)')"

echo "==> Deploy Harvester (private)…"
gcloud run deploy harvester \
  --image "$HARV_IMAGE" \
  --region "$REGION" \
  --no-allow-unauthenticated \
  --service-account "$SA" \
  --add-cloudsql-instances "$CLOUDSQL" \
  --set-env-vars HEALTH_CHECK_DB=1 \
  --set-secrets DATABASE_URL=DATABASE_URL:latest,CIQ_API_KEY=CIQ_API_KEY:latest \
  --quiet

HARV_URL="$(gcloud run services describe harvester --region "$REGION" --format='value(status.url)')"

echo "==> Verify API /health (public)…"
curl -fsS "$API_URL/health" | jq . || { echo "API health failed"; exit 1; }

echo "==> Verify Harvester /health (private via ID token)…"
IDT="$(gcloud auth print-identity-token --audiences="$HARV_URL")"
curl -fsS -H "Authorization: Bearer $IDT" "$HARV_URL/health" | jq . || { echo "Harvester health failed"; exit 1; }

echo
echo "All green."
echo "API:       $API_URL"
echo "Harvester: $HARV_URL"
echo
echo "Notes:"
echo "- Cloud SQL attached via Unix socket /cloudsql/$CLOUDSQL (Cloud Run↔SQL recommended). "  # :contentReference[oaicite:6]{index=6}
echo "- Secrets injected from Secret Manager using --set-secrets."                               # :contentReference[oaicite:7]{index=7}
echo "- Each deploy creates a new Cloud Run REVISION; rollback/split traffic if ever needed."   # :contentReference[oaicite:8]{index=8}
