#!/bin/bash
# MWP Concat Context — concatenates the .mwp-context.md cascade from project root to target
# Usage: bash .mwp/concat-context.sh <target-file-or-directory>
# Output to stdout. Run ONCE per chat session when the target is known.

TARGET="${1:-.}"

# Resolve target directory
if [ -f "$TARGET" ]; then
  TARGET_DIR=$(cd "$(dirname "$TARGET")" && pwd)
elif [ -d "$TARGET" ]; then
  TARGET_DIR=$(cd "$TARGET" && pwd)
else
  echo "Error: '$TARGET' not found." >&2
  exit 1
fi

# Find project root — nearest ancestor with .mwp, fallback to git root or CWD
ROOT=""
dir="$TARGET_DIR"
while [ "$dir" != "/" ]; do
  if [ -d "$dir/.mwp" ] || [ -f "$dir/.mwp" ]; then
    ROOT="$dir"
    break
  fi
  dir=$(dirname "$dir")
done
[ -z "$ROOT" ] && ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Build ordered directory list: root → target
rel_path="${TARGET_DIR#"$ROOT"}"
rel_path="${rel_path#/}"

dirs=("$ROOT")
current="$ROOT"
IFS='/' read -ra parts <<< "$rel_path"
for part in "${parts[@]}"; do
  [ -z "$part" ] && continue
  current="$current/$part"
  dirs+=("$current")
done

# Concatenate .mwp-context.md files in root → target order
found=0
for d in "${dirs[@]}"; do
  if [ -f "$d/.mwp-context.md" ]; then
    rel="${d#"$ROOT"}"
    rel="${rel#/}"
    [ -z "$rel" ] && rel="."
    echo "<!-- context: $rel/.mwp-context.md -->"
    cat "$d/.mwp-context.md"
    echo ""
    found=$((found + 1))
  fi
done

if [ "$found" -eq 0 ]; then
  echo "<!-- No .mwp-context.md files found in cascade to: $TARGET -->"
  echo "<!-- Consider creating .mwp-context.md files along the path (see protocol.md) -->"
fi
