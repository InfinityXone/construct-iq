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
