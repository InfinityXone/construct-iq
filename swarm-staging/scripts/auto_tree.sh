#!/bin/bash
# 🌳 Auto tree generator
cd "$(dirname "$0")/.."
tree -L 3 -a > TREE.md
echo "✅ Folder tree updated at $(date)" >> logs/tree_update.log
