#!/bin/bash
# MWP Changes — session-start orientation: recent activity, uncommitted state, topology freshness
# Usage: bash .mwp/changes.sh  (from anywhere inside the project)

_script_dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)
if [ "$(basename "${_script_dir:-}")" = ".mwp" ]; then
  _r=$(dirname "$_script_dir")
else
  _r=$(pwd)
  while [ "$_r" != "/" ] && [ ! -d "$_r/.mwp" ]; do _r=$(dirname "$_r"); done
fi
[ ! -d "$_r/.mwp" ] && { echo "Error: .mwp/ not found." >&2; exit 1; }
cd "$_r" || exit 1

# ── Recent commits ────────────────────────────────────────────────────────────
echo "## Recent Commits"
git log --oneline --stat -5 2>/dev/null || echo "(not a git repository)"
echo ""

# ── Uncommitted changes ───────────────────────────────────────────────────────
echo "## Uncommitted Changes"
status=$(git status --short 2>/dev/null)
if [ -n "$status" ]; then
  echo "$status"
else
  echo "(clean)"
fi
echo ""

# ── Topology freshness ────────────────────────────────────────────────────────
echo "## Topology Freshness"
TOPOLOGY=".mwp/topology.md"
if [ ! -f "$TOPOLOGY" ]; then
  echo "WARNING: topology.md not found — run: bash .mwp/bootstrap.sh"
else
  stale=$(find . \
    \( -name "package.json" -o -name "Cargo.toml" -o -name "pyproject.toml" \
       -o -name "go.mod"    -o -name "build.gradle" -o -name "pom.xml" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/target/*' \
    -newer "$TOPOLOGY" 2>/dev/null)
  if [ -n "$stale" ]; then
    echo "WARNING: topology.md may be stale — project markers changed since last bootstrap:"
    echo "$stale" | while IFS= read -r f; do echo "  - $f"; done
    echo "Re-run: bash .mwp/bootstrap.sh"
  else
    echo "topology.md appears current"
  fi
fi
