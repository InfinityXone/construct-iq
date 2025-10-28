#!/bin/bash
set -e

echo "🧠 Bootstrapping Infinity-X Hydration + Vector + Rosetta Memory System..."
PROJECT_ID="infinity-x-one-swarm-system"
REGION="us-east1"
BUCKET="gcs-bucket-artifacts"
SERVICE="rosetta-memory-api"
MEMORY_DIR="$HOME/infinity-x-one-swarm/bootstrap_hydration_system"
VECTOR_DIR="$MEMORY_DIR/vector_db"

mkdir -p "$MEMORY_DIR" "$VECTOR_DIR"

# 1️⃣ Enable required GCP APIs
echo "🔌 Enabling GCP APIs..."
gcloud services enable firestore.googleapis.com run.googleapis.com pubsub.googleapis.com cloudbuild.googleapis.com aiplatform.googleapis.com

# 2️⃣ Create Firestore in Native mode (if not exists)
echo "📄 Ensuring Firestore exists..."
gcloud firestore databases create --region=$REGION --type=firestore-native 2>/dev/null || true

# 3️⃣ Create Pub/Sub topic for agent sync
echo "📡 Creating Pub/Sub topic..."
gcloud pubsub topics create memory-sync --project=$PROJECT_ID 2>/dev/null || true

# 4️⃣ Setup local FAISS vector DB (Python)
cat > "$MEMORY_DIR/vector_init.py" << 'EOF'
import faiss, os, numpy as np
db_path = os.path.expanduser("~/infinity-x-one-swarm/bootstrap_hydration_system/vector_db/index.faiss")
os.makedirs(os.path.dirname(db_path), exist_ok=True)
if not os.path.exists(db_path):
    dim = 768
    index = faiss.IndexFlatL2(dim)
    faiss.write_index(index, db_path)
    print("✅ Initialized FAISS index at", db_path)
else:
    print("⚙️ FAISS index already exists.")
EOF

python3 "$MEMORY_DIR/vector_init.py"

# 5️⃣ Create minimal FastAPI Rosetta service
mkdir -p "$MEMORY_DIR/rosetta_api"
cat > "$MEMORY_DIR/rosetta_api/main.py" << 'EOF'
from fastapi import FastAPI, Request
import json, os, faiss, numpy as np

app = FastAPI(title="Rosetta Memory API")

VECTOR_PATH = os.path.expanduser("~/infinity-x-one-swarm/bootstrap_hydration_system/vector_db/index.faiss")
index = faiss.read_index(VECTOR_PATH)

@app.post("/embed")
async def embed_memory(request: Request):
    body = await request.json()
    text = body.get("text", "")
    vector = np.random.rand(1, 768).astype('float32')  # placeholder embedding
    index.add(vector)
    faiss.write_index(index, VECTOR_PATH)
    return {"status": "stored", "vector_id": int(index.ntotal)}

@app.get("/stats")
async def stats():
    return {"total_vectors": int(index.ntotal), "path": VECTOR_PATH}
EOF

# 6️⃣ Build and deploy to Cloud Run
echo "🚀 Deploying Rosetta Memory API to Cloud Run..."
gcloud run deploy $SERVICE \
  --source "$MEMORY_DIR/rosetta_api" \
  --project=$PROJECT_ID \
  --region=$REGION \
  --allow-unauthenticated \
  --cpu=1 --memory=512Mi --platform=managed

# 7️⃣ Generate schema documentation
cat > "$MEMORY_DIR/SCHEMA_HYDRATION.md" << 'EOF'
# 🧬 Infinity-X Hydration Memory Schema

**Collections:**
- `schema_versions`: Tracks schema revisions, migrations, and timestamps.
- `hydration_memory`: Core contextual memory data (JSON format).
- `vector_index`: Vector embedding metadata linking FAISS/Vertex IDs.

**Cloud Integration:**
- Firestore: Primary storage
- GCS: Nightly backups
- Pub/Sub: Sync bus for memory gateway
- Cloud Run: Rosetta API
EOF

# 8️⃣ Schedule nightly sync (GCP Scheduler + Cloud Run call)
gcloud scheduler jobs create http hydration-sync \
  --schedule="0 2 * * *" \
  --uri="$(gcloud run services describe $SERVICE --format='value(status.url)')/stats" \
  --http-method=GET \
  --time-zone="America/New_York" \
  --project=$PROJECT_ID 2>/dev/null || true

echo "✅ Hydration Memory System bootstrapped successfully!"
echo "🧩 Local path: $MEMORY_DIR"
echo "🌐 Rosetta API deployed to Cloud Run."
