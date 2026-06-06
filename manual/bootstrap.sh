#!/bin/bash
# MWP Bootstrap — generates .mwp/topology.md from the current project structure
# Usage: bash .mwp/bootstrap.sh  (from anywhere inside the project)

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

# Create .mwpignore with defaults if absent
if [ ! -f .mwpignore ]; then
  cat > .mwpignore << 'EOF'
# Project-specific exclusions for workspace map (one pattern per line)
# Used to prune directories from topology crawl.

.git/
node_modules/
target/
dist/
vendor/
build/
.cache/

# Patterns:
# generated/
# fixtures/
# *.snap
EOF
fi

# Build find -prune expression from .mwpignore
P_PATTERNS=""
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line// /}" ]] && continue
  
  p=$(echo "$line" | sed 's|[[:space:]]*$||; s|/*$||')
  [[ "$p" != ./* ]] && p="./$p"
  
  if [ -z "$P_PATTERNS" ]; then
    P_PATTERNS="-path '$p' -o -path '$p/*'"
  else
    P_PATTERNS="$P_PATTERNS -o -path '$p' -o -path '$p/*'"
  fi
done < .mwpignore

# Helper for running find with pruning
mwp_find() {
  local maxdepth_arg=""
  [ -n "$1" ] && maxdepth_arg="-maxdepth $1"
  shift
  
  if [ -n "$P_PATTERNS" ]; then
    eval "find . $maxdepth_arg \( $P_PATTERNS \) -prune -o \( $@ \) -print"
  else
    find . $maxdepth_arg \( $@ \) -print
  fi
}

{
  echo "# Workspace Topology"
  echo ""
  echo "## Sub-project Markers"
  mwp_find 4 -name "package.json" -o -name "Cargo.toml" -o -name "pyproject.toml" \
             -o -name "go.mod"    -o -name "build.gradle" -o -name "pom.xml" \
             -o -name ".mwp" \
    | sort | while IFS= read -r f; do echo "- $f"; done
  echo ""

  echo "## .mwp-context.md Files"
  mwp_find "" -name ".mwp-context.md" \
    | grep -v '\./\.mwp/' \
    | sort | while IFS= read -r f; do echo "- $f"; done
  echo ""

  echo "## Entry Points"
  mwp_find 5 -name "index.ts" -o -name "index.js" -o -name "main.ts" \
             -o -name "main.rs" -o -name "main.go" -o -name "main.py" \
             -o -name "app.ts"  -o -name "server.ts" \
    | sort | while IFS= read -r f; do echo "- $f"; done
  echo ""

  echo "## Infrastructure and Config"
  mwp_find 4 -name "Dockerfile" -o -name "docker-compose*.yml" \
             -o -name ".env.example" \
             -o -name "vite.config.*" -o -name "next.config.*" \
             -o -name "*.config.ts"   -o -name "*.config.js" \
    | sort | while IFS= read -r f; do echo "- $f"; done
  mwp_find 3 -path '*/.github/workflows/*.yml' -o -name ".travis.yml" \
             -o -name "Jenkinsfile" \
    | sort | while IFS= read -r f; do echo "- $f"; done
  echo ""

  echo "## Monorepo Workspace Files"
  mwp_find 2 -name "pnpm-workspace.yaml" -o -name "lerna.json" \
             -o -name "nx.json"          -o -name "turbo.json" \
             -o -name "rush.json" \
    | sort | while IFS= read -r f; do echo "- $f"; done
  echo ""

  echo "## API and Schema Definitions"
  mwp_find 5 -name "openapi.yml" -o -name "openapi.yaml" -o -name "swagger.yml" \
             -o -name "swagger.yaml" -o -name "*.graphql" -o -name "*.proto" \
             -o -name "*.prisma"     -o -name "schema.sql" \
    | sort | while IFS= read -r f; do echo "- $f"; done
  echo ""

  echo "## README Files"
  mwp_find 3 -name "README.md" \
    | sort | while IFS= read -r f; do echo "- $f"; done
  echo ""
} > .mwp/topology.md

echo "Done → .mwp/topology.md"
