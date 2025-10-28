#!/bin/bash
# ============================================================
# Infinity-X One — System Blueprint Generator
# Generates a markdown checklist of all active services
# ============================================================

PROJECT="infinity-x-one-swarm-system"
DEST="$HOME/infinity-x-one-swarm"
REGISTRY="$DEST/SERVICE_REGISTRY.json"
BLUEPRINT="$DEST/SYSTEM_BLUEPRINT.md"

echo "🧬 Generating System Blueprint for project: $PROJECT"

# Ensure destination folder exists
mkdir -p "$DEST"

# Step 1 — Pull Cloud Run services
echo "🔍 Fetching Cloud Run registry..."
gcloud run services list \
  --project=$PROJECT \
  --region=us-east1 \
  --format="json" > "$REGISTRY"

# Step 2 — Write Markdown header
date=$(date)
cat > "$BLUEPRINT" <<EOF
# Infinity-X One — System Blueprint

📅 Generated: $date  
🌐 Project: $PROJECT  

| Module | Found | Endpoint | Health | Notes |
|--------|--------|-----------|---------|-------|
EOF

# Step 3 — Define core modules
MODULES=("orchestrator" "infinity-agent" "visionary-agent" "strategist-agent" "financial-agent" "codex-agent" "memory-gateway" "headless-api" "dashboard")

for module in "${MODULES[@]}"; do
  url=$(jq -r ".[] | select(.metadata.name==\"$module\") | .status.url" "$REGISTRY")
  ready=$(jq -r ".[] | select(.metadata.name==\"$module\") | .status.conditions[]? | select(.type==\"Ready\") | .status" "$REGISTRY")
  
  if [[ "$url" == "null" || -z "$url" ]]; then
    echo "| $module | ❌ | — | — | Missing or undeployed |" >> "$BLUEPRINT"
  else
    if [[ "$ready" == "True" ]]; then
      echo "| $module | ✅ | $url | 💚 Healthy | Active Cloud Run Service |" >> "$BLUEPRINT"
    else
      echo "| $module | ⚠️ | $url | ❌ Unhealthy | Needs review |" >> "$BLUEPRINT"
    fi
  fi
done

# Step 4 — Add summary footer
cat >> "$BLUEPRINT" <<EOF

---

✅ **Legend:**  
- ✅ Found: Service deployed and accessible  
- ⚠️ Warning: Service deployed but not ready  
- ❌ Missing: Not found in Cloud Run registry  

📘 File: $BLUEPRINT  
EOF

echo "✅ Blueprint generated at: $BLUEPRINT"
