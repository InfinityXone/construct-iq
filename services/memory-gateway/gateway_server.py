from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from typing import Optional, Dict
import json, os

# Try to load Google Cloud Run client
try:
    from google.cloud import run_v2
except ImportError:
    run_v2 = None

print("🚀 Starting Infinity-X Memory Gateway from gateway_server.py")

app = FastAPI(title="Infinity-X Memory Gateway")

STATE_FILE = os.path.expanduser("~/infinity-x-one-swarm/memory-gateway/state_snapshot.json")

# ---------- MODELS ----------

class GPTMemoryAction(BaseModel):
    action: str
    agent_id: Optional[str] = None
    key: Optional[str] = None
    value: Optional[str] = None
    metadata: Optional[Dict] = None


class NeuralLink(BaseModel):
    name: str
    url: str
    auth_token: Optional[str] = None
    auto_sync: bool = True


# ---------- MEMORY CORE ----------

memory_state: Dict[str, str] = {}
links: Dict[str, Dict] = {}


def save_state():
    """Save memory and links to disk"""
    with open(STATE_FILE, "w") as f:
        json.dump({"memory": memory_state, "links": links}, f, indent=2)


def load_state():
    """Load state from file"""
    global memory_state, links
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r") as f:
            data = json.load(f)
            memory_state.update(data.get("memory", {}))
            links.update(data.get("links", {}))


# ---------- ROUTES ----------

@app.on_event("startup")
def startup_event():
    load_state()


@app.get("/health")
def health():
    return {"status": "ok", "component": "memory-gateway"}


@app.post("/memory/remember")
def remember(item: GPTMemoryAction):
    if not item.key or not item.value:
        raise HTTPException(status_code=400, detail="key and value required")
    memory_state[item.key] = item.value
    save_state()
    return {"status": "ok", "message": f"Memory stored under key '{item.key}'"}


@app.post("/memory/recall")
def recall(item: GPTMemoryAction):
    if not item.key:
        raise HTTPException(status_code=400, detail="key required")
    return {"status": "ok", "value": memory_state.get(item.key)}


@app.post("/memory/hydrate")
def hydrate():
    load_state()
    return {"status": "ok", "restored": True, "keys": list(memory_state.keys())}


@app.get("/memory/dehydrate")
def dehydrate():
    save_state()
    return {"status": "ok", "saved": True, "path": STATE_FILE}


@app.post("/memory/link")
def link_endpoint(link: NeuralLink):
    links[link.name] = {"url": link.url, "auto_sync": link.auto_sync}
    save_state()
    return {"status": "ok", "message": f"Linked {link.name}"}


# ---------- NEW: GCP Cloud Run Integration ----------

@app.get("/gcp/run/services")
def list_run_services(
    project: str = Query(..., description="GCP Project ID"),
    region: str = Query(..., description="GCP region name")
):
    if run_v2 is None:
        raise HTTPException(status_code=503, detail="google-cloud-run library not installed")

    try:
        client = run_v2.ServicesClient()
        parent = f"projects/{project}/locations/{region}"
        services = [
            {"name": s.name, "traffic": [t.percent for t in s.traffic]}
            for s in client.list_services(parent=parent)
        ]
        return {
            "project": project,
            "region": region,
            "service_count": len(services),
            "services": services,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"GCP API error: {str(e)}")
