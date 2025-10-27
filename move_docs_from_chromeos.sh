#!/usr/bin/env bash
# move_docs_from_chromeos.sh — Pulls GPT docs directly from Chrome OS Downloads into Construct-IQ

SRC="/mnt/chromeos/MyFiles/Downloads"
DEST="$HOME/construct-iq/docs/system"

mkdir -p "$DEST"
echo "📁 Moving GPT system docs from Chrome OS to $DEST"

for i in $(seq -w 1 25); do
  FILE=$(find "$SRC" -maxdepth 1 -name "${i}_*.md" -print -quit)
  if [[ -n "$FILE" ]]; then
    cp "$FILE" "$DEST/"
    echo "✅ Moved: $(basename "$FILE")"
  else
    echo "⚠️  Missing doc for prefix $i"
  fi
done

echo "🧠 Done. Docs should now be in $DEST"
