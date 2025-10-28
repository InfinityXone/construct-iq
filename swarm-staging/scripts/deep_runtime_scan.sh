#!/bin/bash
# ==========================================================
# Infinity-X One Orchestrator Runtime Deep Scanner
# Recursively scans ~/infinity-x-one-swarm/orchestrator
# to determine which runtime (Node.js, Python, Go, etc.)
# ==========================================================

TARGET_DIR=~/infinity-x-one-swarm/orchestrator

if [ ! -d "$TARGET_DIR" ]; then
  echo "❌ Orchestrator directory not found: $TARGET_DIR"
  exit 1
fi

echo "🔍 Scanning $TARGET_DIR for runtime indicators..."
echo "----------------------------------------------------------"

find "$TARGET_DIR" -type f \( \
  -name "package.json" -o \
  -name "server.js" -o \
  -name "app.js" -o \
  -name "*.py" -o \
  -name "go.mod" -o \
  -name "Dockerfile" \
\) 2>/dev/null | while read file; do
  echo "➡️ Found: $file"
  head -n 5 "$file" 2>/dev/null | sed 's/^/   /'
  echo "----------------------------------------------------------"
done

echo "🧠 Runtime guess:"
if find "$TARGET_DIR" -name "package.json" | grep -q .; then
  echo "✅ Likely Node.js project (package.json present)"
elif find "$TARGET_DIR" -name "*.py" | grep -q .; then
  echo "🐍 Likely Python-based project"
elif find "$TARGET_DIR" -name "go.mod" | grep -q .; then
  echo "💼 Likely Go-based project"
elif grep -qi "FROM node" "$TARGET_DIR"/Dockerfile 2>/dev/null; then
  echo "✅ Dockerfile indicates Node.js"
elif grep -qi "FROM python" "$TARGET_DIR"/Dockerfile 2>/dev/null; then
  echo "🐍 Dockerfile indicates Python"
elif grep -qi "FROM golang" "$TARGET_DIR"/Dockerfile 2>/dev/null; then
  echo "💼 Dockerfile indicates Go"
else
  echo "⚠️  No clear runtime found — may be dynamically generated."
fi
