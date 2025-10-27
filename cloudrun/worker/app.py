from flask import Flask, jsonify
app = Flask(__name__)

@app.get("/")
def root():
    routes = sorted([str(r) for r in app.url_map.iter_rules() if r.endpoint != "static"])
    return jsonify({"ok": True, "service": "harvester", "routes": routes})

# keep /healthz, but add /health and /hz
@app.get("/healthz")
@app.get("/health")
@app.get("/hz")
def health():
    return jsonify({"ok": True, "service": "harvester", "db": "skipped"})
