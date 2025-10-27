#!/usr/bin/env bash
# Move uploaded GPT system docs into construct-iq/docs/system

SRC_DIR="$HOME"
DEST_DIR="$HOME/construct-iq/docs/system"

mkdir -p "$DEST_DIR"
echo "📁 Moving GPT system docs to $DEST_DIR"

PREFIXES=(01 02 04 06 07 08 09 10 11 12 13 14 15 17 18 19 20 21 22 23 24 25)

for prefix in "${PREFIXES[@]}"; do
  FILE=$(find "$SRC_DIR" -maxdepth 1 -type f -name "${prefix}_*.md" -print -quit)
  if [[ -n "$FILE" ]]; then
    cp "$FILE" "$DEST_DIR/"
    echo "✅ Moved: $(basename "$FILE")"
  else
    echo "⚠️  Missing doc for prefix $prefix"
  fi
done

echo "🧠 Dev docs now live in $DEST_DIR"
