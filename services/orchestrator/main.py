#!/usr/bin/env python3
# =========================================================
# Infinity-X One Orchestrator (Enhanced Python HTTP Service)
# Core service entrypoint for Cloud Run + Infinity Swarm Ops
# =========================================================

from flask import Flask, jsonify
import subprocess
import datetime
import platform
import socket
import os
import time

app = Flask(__name__)
start_time = time.time()

# =========================================================
# 🧩 Helper functions
# =========================================================
def get_uptime():
    uptime_seconds = time.time() - start_time
    return round(uptime_seconds, 2)

def run_shell(cmd):
    """Executes a shell command and returns stdout/stderr safely."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except Exception as e:
        return "", str(e), 1

# =========================================================
# 🌐 Endpoints
# =========================================================
@app.route("/health", methods=["GET"])
def health():
    """Basic heartbeat endpoint"""
    return jsonify({
        "service": "orchestrator",
        "status": "healthy",
        "uptime": get_uptime(),
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z"
    }), 200

@app.route("/status", methods=["GET"])
def status():
    """Returns runtime and system status info"""
    hostname = socket.gethostname()
    return jsonify({
        "service": "orchestrator",
        "host": hostname,
        "os": platform.system(),
        "python": platform.python_version(),
        "uptime_seconds": get_uptime(),
        "time": datetime.datetime.utcnow().isoformat() + "Z"
    }), 200

@app.route("/info", methods=["GET"])
def info():
    """Provides static and dynamic info about the environment"""
    project = os.environ.get("GOOGLE_CLOUD_PROJECT", "unknown")
    region = os.environ.get("GOOGLE_CLOUD_REGION", "us-east1")
    git_rev, _, _ = run_shell(["git", "rev-parse", "--short", "HEAD"])
    return jsonify({
        "project": project,
        "region": region,
        "git_revision": git_rev or "n/a",
        "env": {k: v for k, v in os.environ.items() if k.startswith(("GOOGLE_", "INF_", "PROJECT"))}
    }), 200

@app.route("/backup", methods=["POST"])
def backup():
    """Triggers the backup routine"""
    backup_script = os.path.expanduser("~/infinity-x-one-swarm/scripts/minimal_backup.sh")

    if not os.path.exists(backup_script):
        return jsonify({
            "error": "Backup script not found",
            "path": backup_script
        }), 500

    stdout, stderr, code = run_shell(["bash", backup_script])
    return jsonify({
        "status": "success" if code == 0 else "failed",
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
        "stdout": stdout,
        "stderr": stderr
    }), 200 if code == 0 else 500

# =========================================================
# 🧠 Entry point
# =========================================================
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    print(f"🚀 Orchestrator service online — listening on port {port}")
    app.run(host="0.0.0.0", port=port)
