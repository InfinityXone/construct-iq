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
