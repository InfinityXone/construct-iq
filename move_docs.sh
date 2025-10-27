#!/usr/bin/env bash
# move_docs.sh — Moves GPT system docs into construct-iq repo's docs/system folder

DEST=~/construct-iq/docs/system
mkdir -p "$DEST"

echo "📁 Moving GPT system docs to $DEST"

for i in $(seq -w 1 25); do
  FILE="$(ls ~/Downloads/${i}_* 2>/dev/null | head -n1)"
  if [[ -n "$FILE" ]]; then
    cp "$FILE" "$DEST/"
    echo "✅ Moved: $(basename "$FILE")"
  else
    echo "⚠️  Missing doc for prefix $i"
  fi
done

echo "🧠 Dev docs ready in $DEST"
