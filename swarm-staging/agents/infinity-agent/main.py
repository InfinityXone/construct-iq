from fastapi import FastAPI, Request
import os, time, json, httpx

app = FastAPI()
start_time = time.time()
SERVICE = os.getenv("SERVICE_NAME", "unknown")

@app.get("/health")
def health():
    return {"service": SERVICE, "status": "healthy", "uptime": round(time.time() - start_time, 2)}

@app.get("/status")
def status():
    return {
        "service": SERVICE,
        "version": os.getenv("SERVICE_VERSION", "latest"),
        "memory_gateway": os.getenv("MEMORY_GATEWAY_URL", "unset"),
        "uptime_seconds": round(time.time() - start_time, 2)
    }

@app.post("/process")
async def process(request: Request):
    data = await request.json()
    return {"service": SERVICE, "received": data, "timestamp": time.time()}
