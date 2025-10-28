# ==========================================
# 🧠 Infinity-X One — Memory Gateway API (Final Unified Release)
# ==========================================
from fastapi import FastAPI, Request
import os, json
from datetime import datetime
from rosetta_client import hydrate

# Initialize FastAPI app
app = FastAPI(title="Infinity-X Memory Gateway", version="1.0.0")

# ------------------------------------------
# 🧩 File paths and helpers
# ------------------------------------------
BASE_DIR = "/tmp"
STATE_PATH = os.path.join(BASE_DIR, "state_snapshot.json")
MEMORY_STORE = os.path.join(BASE_DIR, "memory_store.json")

def load_memory():
    """Load stored memory from disk."""
    if os.path.exists(MEMORY_STORE):
        with open(MEMORY_STORE, "r") as f:
            try:
                return json.load(f)
            except json.JSONDecodeError:
                return {}
    return {}

def save_memory(data):
    """Persist memory state to disk."""
    with open(MEMORY_STORE, "w") as f:
        json.dump(data, f, indent=2)

# ------------------------------------------
# 🩺 Health Endpoint
# ------------------------------------------
@app.get("/health")
def health():
    """Check service health."""
    uptime = datetime.utcnow().isoformat()
    return {"service": "memory-gateway", "status": "healthy", "uptime": uptime}

# ------------------------------------------
# 💾 Memory Dump (Dehydrate)
# ------------------------------------------
@app.get("/memory/dump")
def memory_dump():
    """Save current in-memory state to snapshot."""
    memory = load_memory()
    snapshot = {
        "timestamp": datetime.utcnow().isoformat(),
        "agent": "Infinity-X-One",
        "version": "1.0.0-final",
        "state": memory,
    }

    with open(STATE_PATH, "w") as f:
        json.dump(snapshot, f, indent=2)

    return {
        "status": "saved",
        "path": STATE_PATH,
        "size": os.path.getsize(STATE_PATH),
        "keys": list(memory.keys()),
        "timestamp": snapshot["timestamp"],
    }

# ------------------------------------------
# 🔄 Memory Restore (Hydrate)
# ------------------------------------------
@app.post("/memory/restore")
async def memory_restore(request: Request):
    """Restore persisted memory snapshot to active state."""
    try:
        payload = await request.json()
        with open(STATE_PATH, "w") as f:
            json.dump(payload, f, indent=2)

        hydrate("Infinity-X-One")
        return {
            "status": "ok",
            "restored": True,
            "keys": list(payload.keys()),
            "timestamp": datetime.utcnow().isoformat(),
        }
    except Exception as e:
        return {"status": "failed", "error": str(e)}

# ------------------------------------------
# 🧠 Memory Store (Remember)
# ------------------------------------------
@app.post("/memory/remember")
async def memory_remember(request: Request):
    """Store a memory key-value pair."""
    payload = await request.json()
    key = payload.get("key")
    value = payload.get("value")

    if not key or value is None:
        return {"status": "error", "message": "Missing 'key' or 'value'."}

    data = load_memory()
    data[key] = {
        "value": value,
        "agent_id": payload.get("agent_id", "Infinity-X-One"),
        "timestamp": datetime.utcnow().isoformat(),
    }
    save_memory(data)
    return {"status": "ok", "message": f"Memory stored under key '{key}'"}

# ------------------------------------------
# 🔍 Memory Recall
# ------------------------------------------
@app.post("/memory/recall")
async def memory_recall(request: Request):
    """Retrieve stored memory by key."""
    payload = await request.json()
    key = payload.get("key")
    if not key:
        return {"status": "error", "message": "Missing 'key'."}

    data = load_memory()
    if key not in data:
        return {"status": "error", "message": f"No memory found for '{key}'"}

    return {"status": "ok", "value": data[key]["value"], "timestamp": data[key]["timestamp"]}

# ------------------------------------------
# 🔗 Neural Link Registration
# ------------------------------------------
@app.post("/memory/link")
async def memory_link(request: Request):
    """Register or link another agent node."""
    payload = await request.json()
    name = payload.get("name")
    url = payload.get("url")
    token = payload.get("auth_token")
    auto_syn_
