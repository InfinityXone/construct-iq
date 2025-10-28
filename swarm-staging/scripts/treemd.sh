#!/bin/bash
echo "🌲 Generating live directory tree..."
cd ~/infinity-x-one-swarm
tree -I ".git|node_modules|.venv|__pycache__" > REPO_TREE.md
echo "✅ REPO_TREE.md updated."
