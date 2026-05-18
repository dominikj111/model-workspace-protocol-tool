# Workspace Mapping Protocol

**Structure:** Bootstrap (generates `topology.md`) → During the session (read both files → cascade CONTEXT.md → write to `discoveries.md` → proceed) → Persistence rules → Five context layers.

Both files live in `.mwp-root/`. `topology.md` is regenerable. `discoveries.md` is permanent, human-curated accumulation.

---

## Bootstrap (once, or when topology changes)

Copy-paste and run the entire block from the project root. Writes directly to `topology.md`.

```bash
mkdir -p .mwp-root && {

# Create .mwpignore with commented defaults if absent
[ -f .mwpignore ] || cat > .mwpignore << 'EOF'
# Project-specific exclusions for workspace map (one pattern per line, grep -vE semantics)
# node_modules/, .git/, target/ are always excluded regardless of this file
# generated/
# vendor/
# fixtures/
# *.snap
EOF

# Filter: applies .mwpignore patterns on top of the hardcoded base exclusions
mwp_filter() {
  local pattern
  pattern=$(grep -v '^[[:space:]]*#' .mwpignore 2>/dev/null \
            | grep -v '^[[:space:]]*$' \
            | tr '\n' '|' | sed 's/|$//')
  [ -n "$pattern" ] && grep -vE "$pattern" || cat
}

# Sub-project root markers
{
  echo "# Workspace Topology"
  echo ""
  echo "## Sub-project Markers"
  find . -maxdepth 4 \
    \( -name "package.json" -o -name "Cargo.toml" -o -name "pyproject.toml" \
       -o -name "go.mod"    -o -name "build.gradle" -o -name "pom.xml" \
       -o -name ".mwp-root" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/target/*' \
    | sort | mwp_filter | while read f; do echo "- $f"; done
  echo ""
} > .mwp-root/topology.md

# CONTEXT.md files
{
  echo "## CONTEXT.md Files"
  find . -name "CONTEXT.md" \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/target/*' \
    | sort | mwp_filter | while read f; do echo "- $f"; done
  echo ""
} >> .mwp-root/topology.md

# Entry points
{
  echo "## Entry Points"
  find . -maxdepth 5 \
    \( -name "index.ts" -o -name "index.js" -o -name "main.ts" \
       -o -name "main.rs" -o -name "main.go" -o -name "main.py" \
       -o -name "app.ts"  -o -name "server.ts" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/target/*' \
    | sort | mwp_filter | while read f; do echo "- $f"; done
  echo ""
} >> .mwp-root/topology.md

# Infrastructure and config files
{
  echo "## Infrastructure and Config"
  find . -maxdepth 4 \
    \( -name "Dockerfile" -o -name "docker-compose*.yml" \
       -o -name ".env.example" \
       -o -name "vite.config.*" -o -name "next.config.*" \
       -o -name "*.config.ts"   -o -name "*.config.js" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    | sort | mwp_filter | while read f; do echo "- $f"; done
  find . -maxdepth 3 \
    \( -path '*/.github/workflows/*.yml' -o -name ".travis.yml" \
       -o -name "Jenkinsfile" \) \
    | sort | mwp_filter | while read f; do echo "- $f"; done
  echo ""
} >> .mwp-root/topology.md

# Monorepo workspace files
{
  echo "## Monorepo Workspace Files"
  find . -maxdepth 2 \
    \( -name "pnpm-workspace.yaml" -o -name "lerna.json" \
       -o -name "nx.json"          -o -name "turbo.json" \
       -o -name "rush.json" \) \
    -not -path '*/.git/*' \
    | sort | mwp_filter | while read f; do echo "- $f"; done
  echo ""
} >> .mwp-root/topology.md

# API and schema definitions
{
  echo "## API and Schema Definitions"
  find . -maxdepth 5 \
    \( -name "openapi.yml" -o -name "openapi.yaml" -o -name "swagger.yml" \
       -o -name "swagger.yaml" -o -name "*.graphql" -o -name "*.proto" \
       -o -name "*.prisma"     -o -name "schema.sql" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/target/*' \
    | sort | mwp_filter | while read f; do echo "- $f"; done
  echo ""
} >> .mwp-root/topology.md

# README files at sub-project roots
{
  echo "## README Files"
  find . -maxdepth 3 -name "README.md" \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    | sort | mwp_filter | while read f; do echo "- $f"; done
  echo ""
} >> .mwp-root/topology.md

echo "Done → .mwp-root/topology.md"
}
```

**Regenerate topology when:** new sub-projects appear, manifests are added or removed, major directories are restructured.

---

## During the session

At session start, read both files:

- `.mwp-root/topology.md` — structural index of the project
- `.mwp-root/discoveries.md` — accumulated findings from previous sessions (may not exist yet)

When the target is known, follow this sequence before doing any work:

1. **Read all `CONTEXT.md` files in the cascade to the target.** Run the command below,
   then read only the files whose path is a prefix of the target path (ancestors). Skip
   siblings. Follow only what each file explicitly imports or links.

   ```bash
   find . -name "CONTEXT.md" \
     -not -path '*/node_modules/*' -not -path '*/.git/*' \
     -not -path '*/target/*'       -not -path '*/__pycache__/*' \
     -not -path '*/.mwp-root/*' \
     | sort
   ```

2. **Inject missing findings into `.mwp-root/discoveries.md`** — facts not yet recorded
   that were learned from the cascade or from reading source. Written now for future
   sessions; the current session already has them in context.

3. **Proceed** — context is now enriched from topology, discoveries, and the cascade.

---

## Persistence rules

Write to `discoveries.md`:

- `stack:` — observed language, framework, runtime
- `boundary:` — what this sub-project owns and does not own
- `convention:` — coding or architectural rules in force
- `dependency:` — explicit cross-sub-project relationships
- `constraint:` — hard limits (size, performance, security, compliance)
- `owner:` — team or person responsible

Suffix `?` on any item inferred rather than directly observed:

```markdown
- stack: Node.js, TypeScript
- stack?: tRPC  (inferred from ./backend/package.json dependency)
- boundary: owns HTTP API layer, no direct browser access
- constraint?: bundle < 200 KB  (inferred from ./frontend/README.md)
```

Do **not** write:

- speculative summaries or optimization ideas
- session reasoning or implementation plans
- inferred intentions without a source anchor
- anything not traceable to a file you read

The map is terrain, not work history. Source code and git history cover the work.

---

## Five context layers

| Layer | What it encodes |
| ----- | --------------- |
| L0 | Project identity — what this is, stack, primary constraints |
| L1 | Domain routing — which directory handles what, technology choices |
| L2 | Module scope — public interface, responsibility, and constraints of a directory |
| L3 | Reference — conventions, rules, patterns, skills |
| L4 | Executable constraints — guards and verification checks that confirm L3 rules hold |

L0–L1 applies everywhere. L2–L4 applies within its directory scope and all children.
More specific (closer to target) overrides less specific when they conflict.
`CONTEXT.md` at a directory boundary (where `.mwp-root` exists) stops upward traversal.
