#!/bin/bash
# MWP Context Scaffold — creates a .mwp-context.md stub in a directory
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

DEST="$TARGET/.mwp-context.md"

if [ -f "$DEST" ]; then
  echo ".mwp-context.md already exists at $DEST" >&2
  echo "Edit it directly rather than overwriting." >&2
  exit 1
fi

cat > "$DEST" << 'EOF'
<!-- MWP CONTEXT — replace this entire comment block with a brief paragraph (2-5 sentences).
     Cover: what this directory owns, key constraints, stack choices specific to this scope,
     and anything that would surprise a developer opening it for the first time.
     Keep it tight — this file is loaded into every LLM session targeting this scope. -->
EOF

echo "Created: $DEST"
echo "Ask the user the MWP protocol questions, then replace the stub with a brief paragraph."
