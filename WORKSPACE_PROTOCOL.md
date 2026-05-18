# Workspace Mapping Protocol

**Structure:** Bootstrap (one-time init script) → During the session (cascade read → map update → proceed) → Five context layers.

---

## Bootstrap (once, if the map does not exist or is empty)

Copy-paste and run the entire block from the project root. It writes directly to the map.

```bash
mkdir -p .mwp-root && {

# Directory tree
{
  echo "# Workspace Map"
  echo ""
  echo "## Directory Tree"
  echo '```'
  find . -maxdepth 5 \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/target/*'       -not -path '*/__pycache__/*' \
    -not -path '*/.mwp/*'         -not -path '*/dist/*' \
    -not -path '*/build/*'        -not -path '*/.next/*' \
    -not -path '*/.turbo/*'       -not -path '*/coverage/*' \
    | sort
  echo '```'
  echo ""
} > .mwp-root/WORKSPACE_MAP.md

# Sub-project root markers
{
  echo "## Sub-project Markers"
  find . -maxdepth 4 \
    \( -name "package.json" -o -name "Cargo.toml" -o -name "pyproject.toml" \
       -o -name "go.mod"    -o -name "build.gradle" -o -name "pom.xml" \
       -o -name ".mwp-root" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/target/*' \
    | sort | while read f; do echo "- $f"; done
  echo ""
} >> .mwp-root/WORKSPACE_MAP.md

# CONTEXT.md files
{
  echo "## CONTEXT.md Files"
  find . -name "CONTEXT.md" \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/target/*' \
    | sort | while read f; do echo "- $f"; done
  echo ""
} >> .mwp-root/WORKSPACE_MAP.md

# Entry points
{
  echo "## Entry Points"
  find . -maxdepth 5 \
    \( -name "index.ts" -o -name "index.js" -o -name "main.ts" \
       -o -name "main.rs" -o -name "main.go" -o -name "main.py" \
       -o -name "app.ts"  -o -name "server.ts" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/target/*' \
    | sort | while read f; do echo "- $f"; done
  echo ""
} >> .mwp-root/WORKSPACE_MAP.md

# Infrastructure and config files
{
  echo "## Infrastructure and Config"
  find . -maxdepth 4 \
    \( -name "Dockerfile" -o -name "docker-compose*.yml" \
       -o -name ".env.example" \
       -o -name "vite.config.*" -o -name "next.config.*" \
       -o -name "*.config.ts"   -o -name "*.config.js" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    | sort | while read f; do echo "- $f"; done
  find . -maxdepth 3 \
    \( -path '*/.github/workflows/*.yml' -o -name ".travis.yml" \
       -o -name "Jenkinsfile" \) \
    | sort | while read f; do echo "- $f"; done
  echo ""
} >> .mwp-root/WORKSPACE_MAP.md

# Monorepo workspace files
{
  echo "## Monorepo Workspace Files"
  find . -maxdepth 2 \
    \( -name "pnpm-workspace.yaml" -o -name "lerna.json" \
       -o -name "nx.json"          -o -name "turbo.json" \
       -o -name "rush.json" \) \
    -not -path '*/.git/*' \
    | sort | while read f; do echo "- $f"; done
  echo ""
} >> .mwp-root/WORKSPACE_MAP.md

# API and schema definitions
{
  echo "## API and Schema Definitions"
  find . -maxdepth 5 \
    \( -name "openapi.yml" -o -name "openapi.yaml" -o -name "swagger.yml" \
       -o -name "swagger.yaml" -o -name "*.graphql" -o -name "*.proto" \
       -o -name "*.prisma"     -o -name "schema.sql" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/target/*' \
    | sort | while read f; do echo "- $f"; done
  echo ""
} >> .mwp-root/WORKSPACE_MAP.md

# README files at sub-project roots
{
  echo "## README Files"
  find . -maxdepth 3 -name "README.md" \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    | sort | while read f; do echo "- $f"; done
  echo ""
} >> .mwp-root/WORKSPACE_MAP.md

# Placeholder sections for LLM to fill in
{
  echo "## Sub-project Topology"
  echo "<!-- Add one entry per sub-project: nature, stack, key constraints, boundaries -->"
  echo ""
  echo "## Conventions and Rules"
  echo "<!-- Discovered rules and constraints, grouped by path scope -->"
  echo ""
} >> .mwp-root/WORKSPACE_MAP.md

echo "Done → .mwp-root/WORKSPACE_MAP.md"
}
```

Do not re-run unless the map is empty or you want to regenerate it from scratch.

---

## During the session

When the target is known, follow this sequence before doing any work:

1. **Read all `CONTEXT.md` files in the cascade to the target.** Run the command below,
   then read only the files whose path is a prefix of the target path (ancestors). Skip
   siblings. Follow only what each file explicitly imports or links.

   ```bash
   find . -name "CONTEXT.md" \
     -not -path '*/node_modules/*' -not -path '*/.git/*' \
     -not -path '*/target/*'       -not -path '*/__pycache__/*' \
     -not -path '*/.mwp/*' \
     | sort
   ```

2. **Inject any missing information into `.mwp-root/WORKSPACE_MAP.md`.** Everything
   learned from the cascade that is not yet in the map goes in now — as list items,
   anchored by relative path. The map is read once at session start and stays in context;
   subsequent writes persist discoveries for future sessions, not the current one.

3. **Proceed** — the session context is now enriched from both the map and the cascade.

**Format rules for map additions:**

- All items are **list items** — found facts, not prose.
- Every item uses the **relative path** as its anchor (e.g. `./backend/src/api`).
- Project-wide facts go flat under the relevant top-level section.
- Each sub-project gets its own `### ./name` subsection; discoveries within it are flat
  list items — no deeper nesting.

```markdown
## Sub-project Topology

### ./frontend
- stack: ViteJS, React, TypeScript
- owns: browser-facing UI, routing, state management
- bundle constraint: < 200 KB compressed
- consumes: `./packages/shared-types` for API contracts
- ./frontend/src/components — UI primitives, no data fetching
- ./frontend/src/pages — route-level components, may fetch

### ./backend
- stack: Node.js, TypeScript, tRPC
- owns: HTTP API, business logic, DB access
- ./backend/src/api — tRPC router definitions
- ./backend/src/db — Prisma schema and migrations
```

**Do not** log tasks, diffs, or session summaries. The map is terrain, not work history.
Source code and git history cover the work.

---

## Five context layers

| Layer | What it encodes |
| ----- | --------------- |
| L0 | Project identity — what this is, stack, primary constraints |
| L1 | Domain routing — which directory handles what, technology choices |
| L2 | Module scope — public interface, responsibility, and constraints of a directory |
| L3 | Reference — conventions, rules, patterns, skills |

L0–L1 applies everywhere. L2–L3 applies within its directory scope and all children.
More specific (closer to target) overrides less specific when they conflict.
