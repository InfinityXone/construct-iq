#!/usr/bin/env bash
# move_docs_launch.sh — Sync system docs only (01–25) into construct-iq/docs/system

DEST="$HOME/construct-iq/docs/system"
SRC="$HOME/Downloads"

mkdir -p "$DEST"
echo "📁 Moving GPT system docs to $DEST"

for i in $(seq -w 1 25); do
  FILE=$(find "$SRC" -maxdepth 1 -name "${i}_*.md" -print -quit)
  if [[ -n "$FILE" ]]; then
    cp "$FILE" "$DEST/"
    echo "✅ Moved: $(basename "$FILE")"
  else
    echo "⚠️  Missing doc for prefix $i"
  fi
done

echo "🧠 Dev docs now live in $DEST"
