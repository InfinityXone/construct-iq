#!/bin/bash
set -e
echo "🧠 Bootstrapping Infinity-X Swarm Rosetta Memory Gateway (Local + Cloud)…"

PROJECT_DIR="$HOME/infinity-x-one-swarm"
BOOT_DIR="$PROJECT_DIR/bootstrap_memory_gateway"
SCHEMA_DIR="$BOOT_DIR/schemas"
API_DIR="$BOOT_DIR/api"
VENV_DIR="$PROJECT_DIR/.venv"

mkdir -p "$BOOT_DIR" "$SCHEMA_DIR" "$API_DIR"

# ---------- 1️⃣ Firestore Schema ----------
cat > "$SCHEMA_DIR/firestore_schema.json" <<'EOF'
{
  "collections": {
    "vector_embeddings": {
      "description": "Stores embedding vectors and metadata",
      "fields": {
        "vector_id": "string",
        "embedding": "array<float>",
        "source": "string",
        "timestamp": "timestamp",
        "metadata": "map"
      }
    },
    "memory_snapshots": {
      "description": "Hydration manifest snapshots",
      "fields": {
        "snapshot_id": "string",
        "vector_count": "integer",
        "bucket_uri": "string",
        "created_at": "timestamp"
      }
    }
  }
}
EOF

# ---------- 2️⃣ FastAPI Memory Gateway ----------
cat > "$API_DIR/main.py" <<'EOF'
from fastapi import FastAPI
from pydantic import BaseModel
from google.cloud import firestore
import faiss, numpy as np, os, json

app = FastAPI(title="Infinity-X Rosetta Memory Gateway")
db = firestore.Client()

INDEX_PATH = os.path.join(os.path.dirname(__file__), "vector_db.index")
DIM = 768
index = faiss.IndexFlatL2(DIM)
if os.path.exists(INDEX_PATH):
    faiss.read_index(INDEX_PATH)

class VectorItem(BaseModel):
    vector_id: str
    embedding: list[float]
    source: str
    metadata: dict | None = None

@app.post("/embed")
def add_vector(item: VectorItem):
    vec = np.array([item.embedding]).astype("float32")
    index.add(vec)
    faiss.write_index(index, INDEX_PATH)
    db.collection("vector_embeddings").document(item.vector_id).set({
        "embedding": item.embedding,
        "source": item.source,
        "metadata": item.metadata or {},
    })
    return {"status": "ok", "stored_id": item.vector_id}

@app.get("/query/{k}")
def query_vectors(k: int = 5):
    n = index.ntotal
    if n == 0:
        return {"results": []}
    vecs = np.random.randn(1, DIM).astype("float32")
    D, I = index.search(vecs, k)
    return {"indices": I.tolist(), "distances": D.tolist()}

@app.get("/")
def health():
    return {"status": "healthy", "total_vectors": index.ntotal}
EOF

# ---------- 3️⃣ Local run helper ----------
cat > "$API_DIR/run_local.sh" <<'EOF'
#!/bin/bash
source "$HOME/infinity-x-one-swarm/.venv/bin/activate"
cd "$(dirname "$0")"
uvicorn main:app --host 0.0.0.0 --port 8080
EOF
chmod +x "$API_DIR/run_local.sh"

# ---------- 4️⃣ Cloud Run deploy template ----------
cat > "$BOOT_DIR/cloudrun_deploy.sh" <<'EOF'
#!/bin/bash
SERVICE="infinity-x-memory-gateway"
PROJECT="infinity-x-one-swarm-system"
REGION="us-east1"
IMAGE="gcr.io/$PROJECT/$SERVICE"
echo "☁️ Building and deploying $SERVICE to Cloud Run..."
gcloud builds submit --tag "$IMAGE" .
gcloud run deploy "$SERVICE" \
  --image "$IMAGE" \
  --project "$PROJECT" \
  --region "$REGION" \
  --platform managed \
  --allow-unauthenticated \
  --cpu 1 --memory 512Mi --max-instances 1
EOF
chmod +x "$BOOT_DIR/cloudrun_deploy.sh"

# ---------- 5️⃣ Manifest ----------
cat > "$BOOT_DIR/HYDRATION_MANIFEST.json" <<'EOF'
{
  "project": "infinity-x-one-swarm-system",
  "firestore_collections": ["vector_embeddings", "memory_snapshots"],
  "vector_dim": 768,
  "faiss_index": "bootstrap_memory_gateway/api/vector_db.index",
  "pubsub_topic": "memory-sync",
  "bucket": "gcs-bucket-artifacts"
}
EOF

echo "✅ Rosetta Memory Gateway scaffold created in $BOOT_DIR"
echo "▶️ To run locally:"
echo "   bash $API_DIR/run_local.sh"
echo "▶️ To deploy to Cloud Run (after verifying IAM & billing):"
echo "   bash $BOOT_DIR/cloudrun_deploy.sh"
