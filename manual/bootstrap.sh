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

# Create .mwpignore with commented defaults if absent
[ -f .mwpignore ] || cat > .mwpignore << 'EOF'
# Project-specific exclusions for workspace map (one pattern per line, grep -vE semantics)
# node_modules/, .git/, target/ are always excluded regardless of this file
# generated/
# vendor/
# fixtures/
# *.snap
EOF

# Filter: applies .mwpignore on top of the hardcoded base exclusions
mwp_filter() {
  local pattern
  pattern=$(grep -v '^[[:space:]]*#' .mwpignore 2>/dev/null \
            | grep -v '^[[:space:]]*$' \
            | tr '\n' '|' | sed 's/|$//')
  if [ -n "$pattern" ]; then grep -vE "$pattern"; else cat; fi
}

{
  # Sub-project root markers
  echo "# Workspace Topology"
  echo ""
  echo "## Sub-project Markers"
  find . -maxdepth 4 \
    \( -name "package.json" -o -name "Cargo.toml" -o -name "pyproject.toml" \
       -o -name "go.mod"    -o -name "build.gradle" -o -name "pom.xml" \
       -o -name ".mwp" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/target/*' \
    | sort | mwp_filter | while IFS= read -r f; do echo "- $f"; done
  echo ""

  # .mwp-context.md files
  echo "## .mwp-context.md Files"
  find . -name ".mwp-context.md" \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/target/*'       -not -path '*/.mwp/*' \
    | sort | mwp_filter | while IFS= read -r f; do echo "- $f"; done
  echo ""

  # Entry points
  echo "## Entry Points"
  find . -maxdepth 5 \
    \( -name "index.ts" -o -name "index.js" -o -name "main.ts" \
       -o -name "main.rs" -o -name "main.go" -o -name "main.py" \
       -o -name "app.ts"  -o -name "server.ts" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/target/*' \
    | sort | mwp_filter | while IFS= read -r f; do echo "- $f"; done
  echo ""

  # Infrastructure and config files
  echo "## Infrastructure and Config"
  find . -maxdepth 4 \
    \( -name "Dockerfile" -o -name "docker-compose*.yml" \
       -o -name ".env.example" \
       -o -name "vite.config.*" -o -name "next.config.*" \
       -o -name "*.config.ts"   -o -name "*.config.js" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    | sort | mwp_filter | while IFS= read -r f; do echo "- $f"; done
  find . -maxdepth 3 \
    \( -path '*/.github/workflows/*.yml' -o -name ".travis.yml" \
       -o -name "Jenkinsfile" \) \
    | sort | mwp_filter | while IFS= read -r f; do echo "- $f"; done
  echo ""

  # Monorepo workspace files
  echo "## Monorepo Workspace Files"
  find . -maxdepth 2 \
    \( -name "pnpm-workspace.yaml" -o -name "lerna.json" \
       -o -name "nx.json"          -o -name "turbo.json" \
       -o -name "rush.json" \) \
    -not -path '*/.git/*' \
    | sort | mwp_filter | while IFS= read -r f; do echo "- $f"; done
  echo ""

  # API and schema definitions
  echo "## API and Schema Definitions"
  find . -maxdepth 5 \
    \( -name "openapi.yml" -o -name "openapi.yaml" -o -name "swagger.yml" \
       -o -name "swagger.yaml" -o -name "*.graphql" -o -name "*.proto" \
       -o -name "*.prisma"     -o -name "schema.sql" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/target/*' \
    | sort | mwp_filter | while IFS= read -r f; do echo "- $f"; done
  echo ""

  # README files at sub-project roots
  echo "## README Files"
  find . -maxdepth 3 -name "README.md" \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    | sort | mwp_filter | while IFS= read -r f; do echo "- $f"; done
  echo ""
} > .mwp/topology.md

echo "Done → .mwp/topology.md"
