#!/bin/bash
# MWP Explore — ad-hoc map of a directory
# Prints to stdout. Nothing is stored.
# Usage: bash .mwp/explore.sh [path]

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

ABS="$TARGET"

# Filter: applies .mwpignore if present in CWD (project root)
mwp_filter() {
  local pattern
  pattern=$(grep -v '^[[:space:]]*#' .mwpignore 2>/dev/null \
            | grep -v '^[[:space:]]*$' \
            | tr '\n' '|' | sed 's/|$//')
  if [ -n "$pattern" ]; then grep -vE "$pattern"; else cat; fi
}

echo "# MWP Explore — $ABS"
echo ""

# ── Directory structure ───────────────────────────────────────────────────────
echo "## Structure"
find "$TARGET" -maxdepth 4 \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/target/*'       -not -path '*/__pycache__/*' \
  -not -path '*/.mwp/*'    -not -path '*/dist/*' \
  -not -path '*/build/*'        -not -path '*/.next/*' \
  -not -path '*/.turbo/*'       -not -path '*/coverage/*' \
  | sort | mwp_filter
echo ""

# ── Sub-project markers ───────────────────────────────────────────────────────
echo "## Sub-project Markers"
find "$TARGET" -maxdepth 3 \
  \( -name "package.json" -o -name "Cargo.toml" -o -name "pyproject.toml" \
     -o -name "go.mod"    -o -name "build.gradle" -o -name "pom.xml" \
     -o -name ".mwp" \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/target/*' \
  | sort | mwp_filter | while IFS= read -r f; do echo "- $f"; done
echo ""

# ── .mwp-context.md files ──────────────────────────────────────────────────────────
echo "## .mwp-context.md Files"
find "$TARGET" -name ".mwp-context.md" \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/target/*'       -not -path '*/.mwp/*' \
  | sort | mwp_filter | while IFS= read -r f; do echo "- $f"; done
echo ""

# ── Entry points ──────────────────────────────────────────────────────────────
echo "## Entry Points"
find "$TARGET" -maxdepth 4 \
  \( -name "index.ts" -o -name "index.js" -o -name "main.ts" \
     -o -name "main.rs" -o -name "main.go" -o -name "main.py" \
     -o -name "app.ts"  -o -name "server.ts" \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  -not -path '*/target/*' \
  | sort | mwp_filter | while IFS= read -r f; do echo "- $f"; done
echo ""

# ── Config and infra ──────────────────────────────────────────────────────────
echo "## Config and Infra"
find "$TARGET" -maxdepth 3 \
  \( -name "Dockerfile" -o -name "docker-compose*.yml" \
     -o -name ".env.example" \
     -o -name "vite.config.*" -o -name "next.config.*" \
     -o -name "*.config.ts"   -o -name "*.config.js" \
     -o -name "openapi.yml"   -o -name "openapi.yaml" \
     -o -name "*.graphql"     -o -name "*.proto" \
     -o -name "*.prisma"      -o -name "schema.sql" \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  | sort | mwp_filter | while IFS= read -r f; do echo "- $f"; done
echo ""

# ── Nearest ancestor .mwp-context.md cascade ──────────────────────────────────────
echo "## Ancestor .mwp-context.md Cascade (from project root)"
dir=$(cd "$TARGET" && pwd)
ancestors=""
while [ "$dir" != "/" ]; do
  if [ -f "$dir/.mwp-context.md" ]; then
    ancestors="$dir/.mwp-context.md\n$ancestors"
  fi
  if [ -d "$dir/.mwp" ] || [ -f "$dir/.mwp" ]; then
    break
  fi
  dir=$(dirname "$dir")
done
if [ -n "$ancestors" ]; then
  printf '%b' "$ancestors" | while IFS= read -r f; do [ -n "$f" ] && echo "- $f"; done
else
  echo "- (none found)"
fi
echo ""
