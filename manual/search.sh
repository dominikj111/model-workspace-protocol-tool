#!/bin/bash
# MWP Search — .mwpignore-aware code search
# Usage: bash .mwp/search.sh <pattern> [path]

PATTERN="$1"
SEARCH_PATH="${2:-.}"

if [ -z "$PATTERN" ]; then
  echo "Usage: bash .mwp/search.sh <pattern> [path]" >&2
  exit 1
fi

# Resolve SEARCH_PATH to absolute before cd-ing to project root
SEARCH_PATH=$(cd "$SEARCH_PATH" 2>/dev/null && pwd) || SEARCH_PATH="${2:-.}"

_script_dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)
if [ "$(basename "${_script_dir:-}")" = ".mwp" ]; then
  _r=$(dirname "$_script_dir")
else
  _r=$(pwd)
  while [ "$_r" != "/" ] && [ ! -d "$_r/.mwp" ]; do _r=$(dirname "$_r"); done
fi
[ ! -d "$_r/.mwp" ] && { echo "Error: .mwp/ not found." >&2; exit 1; }
cd "$_r" || exit 1

# Filter: applies .mwpignore if present in CWD (project root)
mwp_filter() {
  local pattern
  pattern=$(grep -v '^[[:space:]]*#' .mwpignore 2>/dev/null \
            | grep -v '^[[:space:]]*$' \
            | tr '\n' '|' | sed 's/|$//')
  if [ -n "$pattern" ]; then grep -vE "$pattern"; else cat; fi
}

grep -rn "$PATTERN" "$SEARCH_PATH" \
  --exclude-dir=node_modules \
  --exclude-dir=.git \
  --exclude-dir=target \
  --exclude-dir=dist \
  --exclude-dir=build \
  --exclude-dir=.next \
  --exclude-dir=coverage \
  --exclude-dir=__pycache__ \
  --exclude-dir=.mwp \
  2>/dev/null | mwp_filter
