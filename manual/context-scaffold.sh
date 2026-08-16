#!/bin/bash
# MWP Context Scaffold — creates a .mwp-context.yaml stub in a directory
# Usage: bash .mwp/context-scaffold.sh <directory>

TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
  echo "Error: '$TARGET' is not a directory." >&2
  exit 1
fi

# Resolve TARGET to absolute before cd-ing to project root
TARGET=$(cd "$TARGET" && pwd) || exit 1

_script_dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)
if [ "$(basename "${_script_dir:-}")" = ".mwp" ]; then
  _r=$(dirname "$_script_dir")
else
  _r=$(pwd)
  while [ "$_r" != "/" ] && [ ! -d "$_r/.mwp" ]; do _r=$(dirname "$_r"); done
fi
[ ! -d "$_r/.mwp" ] && { echo "Error: .mwp/ not found." >&2; exit 1; }
cd "$_r" || exit 1

DEST="$TARGET/.mwp-context.yaml"

if [ -f "$DEST" ]; then
  echo ".mwp-context.yaml already exists at $DEST" >&2
  echo "Edit it directly rather than overwriting." >&2
  exit 1
fi
if [ -f "$TARGET/.mwp-context.yml" ] || [ -f "$TARGET/.mwp-context.md" ]; then
  echo "A .mwp-context.yml/.md already exists at $TARGET — migrate it first (migrate-to-yaml.sh) or edit in place." >&2
  exit 1
fi

cat > "$DEST" << 'EOF'
schema: 1
# TODO: Set layer (0–4) and scope (recursive or local).
#       Add a description, imports, and guards as needed.
#       See protocol.md for the full schema.
EOF

echo "Created: $DEST"
echo "Ask the user the MWP protocol questions, then replace the comments with a brief paragraph."
