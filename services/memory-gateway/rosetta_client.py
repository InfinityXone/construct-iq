"""
Infinity-X One — Rosetta Memory Client
Simple, safe interface to the Cloud Run Memory Gateway.
"""

import requests, os, json

ROSETTA_URL = os.getenv("ROSETTA_URL", "https://memory-gateway-ru6asaa7vq-ue.a.run.app")

def hydrate(agent: str):
    """Retrieve memory context for a given agent"""
    try:
        r = requests.get(f"{ROSETTA_URL}/memory/query", params={"agent": agent}, timeout=10)
        if r.status_code == 200:
            return r.json()
        return {"status": "failed", "code": r.status_code}
    except Exception as e:
        return {"error": str(e)}

def remember(agent: str, summary: str):
    """Send summarized memory back to Rosetta"""
    payload = {"agent": agent, "summary": summary}
    try:
        r = requests.post(f"{ROSETTA_URL}/memory/write", json=payload, timeout=10)
        if r.status_code == 200:
            return r.json()
        return {"status": "failed", "code": r.status_code}
    except Exception as e:
        return {"error": str(e)}
