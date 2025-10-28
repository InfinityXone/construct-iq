#!/bin/bash
set -e
echo "🚀 Infinity-X One — Full Autonomy Stack with Memory + Self-Heal"

PROJECT_DIR="$HOME/infinity-x-one-swarm"
BUCKET="gs://infinity-x-one-swarm-system-memory"
GATEWAY_URL="https://memory-gateway-ru6asaa7vq-ue.a.run.app"
MEMORY_CLIENT="$PROJECT_DIR/memory-gateway/rosetta_client.py"
LOG="$PROJECT_DIR/AUTONOMY_LOG.txt"

echo "🧭 Starting at $(date)" | tee "$LOG"

# --- 1️⃣ Verify core structure ---
declare -a MODULES=("scripts" "memory-gateway" "orchestrator" "langchain-runtime" \
                    "visionary-agent" "strategist-agent" "financial-agent" "dashboard")
for m in "${MODULES[@]}"; do
  if [ ! -d "$PROJECT_DIR/$m" ]; then
    echo "🩹 Creating missing module: $m" | tee -a "$LOG"
    mkdir -p "$PROJECT_DIR/$m"
    echo "# $m module" > "$PROJECT_DIR/$m/README.md"
  else
    echo "✅ Module exists: $m" | tee -a "$LOG"
  fi
done

# --- 2️⃣ Write Rosetta Memory Client ---
echo "🧬 Writing rosetta_client.py ..." | tee -a "$LOG"
cat > "$MEMORY_CLIENT" <<'EOF'
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
EOF

# --- 3️⃣ Write Rosetta Prompt (recursive growth kernel) ---
cat > "$PROJECT_DIR/ROSETTA_PROMPT.md" <<'EOF'
# 🧠 Infinity-X Rosetta Kernel Prompt

Role: Adaptive Cognitive Node of the Infinity-X Swarm  
Mission: Learn from every cycle, improve precision, coherence, and profitability.

Rules:
1. All learning is logged to Rosetta Memory.
2. No destructive code mutation or network self-replication.
3. Always request peer feedback (strategist ↔ visionary ↔ codex).
4. Operate in balance between autonomy and alignment.

Invocation: "Hydrate. Evaluate. Grow."
EOF

# --- 4️⃣ Self-Heal Routine ---
SELFHEAL="$PROJECT_DIR/scripts/self_heal.sh"
cat > "$SELFHEAL" <<'EOF'
#!/bin/bash
set -e
PROJECT_DIR="$HOME/infinity-x-one-swarm"
LOG="$PROJECT_DIR/SELFHEAL_LOG.txt"

echo "🩺 Running Self-Heal at $(date)" | tee "$LOG"
for m in orchestrator memory-gateway langchain-runtime visionary-agent strategist-agent financial-agent dashboard; do
  if [ ! -d "$PROJECT_DIR/$m" ]; then
    echo "🔧 Re-creating module: $m" | tee -a "$LOG"
    mkdir -p "$PROJECT_DIR/$m"
    echo "# $m recovered" > "$PROJECT_DIR/$m/README.md"
  fi
done
echo "✅ Self-Heal completed." | tee -a "$LOG"
EOF
chmod +x "$SELFHEAL"

# --- 5️⃣ Run Diagnostics (if available) ---
echo "🔎 Running hydration diagnostics..." | tee -a "$LOG"
if [ -f "$PROJECT_DIR/scripts/bootstrap_hydration_diagnostics_v4.sh" ]; then
  bash "$PROJECT_DIR/scripts/bootstrap_hydration_diagnostics_v4.sh" | tee -a "$LOG"
else
  echo "⚠️ Diagnostics script not found — skipping." | tee -a "$LOG"
fi

# --- 6️⃣ Upload results to Cloud Storage ---
echo "☁️ Uploading docs + logs to GCS..." | tee -a "$LOG"
gsutil cp "$PROJECT_DIR"/*.md "$BUCKET/docs/" 2>/dev/null || echo "⚠️ GCS upload skipped." | tee -a "$LOG"
gsutil cp "$PROJECT_DIR"/*LOG*.txt "$BUCKET/logs/" 2>/dev/null || echo "⚠️ Log upload skipped." | tee -a "$LOG"

echo "✅ Full Autonomy Bootstrap Complete — $(date)" | tee -a "$LOG"
echo "   • Memory client: $MEMORY_CLIENT"
echo "   • Self-heal:     $SELFHEAL"
echo "   • Rosetta:       $GATEWAY_URL"
echo "🌙 System initialized and ready."
