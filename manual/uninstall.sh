#!/bin/bash
# MWP Uninstall — removes all MWP artefacts from the project
# Usage: bash .mwp/uninstall.sh  (from anywhere inside the project)

set -e

_script_dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)
if [ "$(basename "${_script_dir:-}")" = ".mwp" ]; then
  _r=$(dirname "$_script_dir")
else
  _r=$(pwd)
  while [ "$_r" != "/" ] && [ ! -d "$_r/.mwp" ]; do _r=$(dirname "$_r"); done
fi
[ ! -d "$_r/.mwp" ] && { echo "Error: .mwp/ not found." >&2; exit 1; }
cd "$_r" || exit 1

# Count context files before removal so we can report them
context_count=$(find . -name ".mwp-context.md" \
  -not -path '*/.git/*' \
  -not -path '*/node_modules/*' \
  -not -path '*/target/*' \
  2>/dev/null | wc -l | tr -d ' ')

printf "\n  This will remove:\n"
printf "    • .mwp/  (tooling directory)\n"
printf "    • %s .mwp-context.md file(s) found in the project tree\n" "$context_count"
printf "    • .mwpignore  (if present)\n"
printf "\n  Continue? [y/N] "
IFS= read -r answer < /dev/tty
printf "\n"

case "$answer" in
  [Yy]*) ;;
  *) echo "  Aborted."; exit 0 ;;
esac

# Remove tooling directory
rm -rf .mwp
echo "  removed  .mwp/"

# Remove context files
if [ "$context_count" -gt 0 ]; then
  find . -name ".mwp-context.md" \
    -not -path '*/.git/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/target/*' \
    -delete
  echo "  removed  $context_count .mwp-context.md file(s)"
fi

# Remove .mwpignore if present
if [ -f ".mwpignore" ]; then
  rm .mwpignore
  echo "  removed  .mwpignore"
fi

printf "\n  MWP removed. Don't forget to clean up your CLAUDE.md.\n\n"
