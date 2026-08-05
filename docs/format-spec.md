# MWP Format Specification

Normative extraction of file formats, algorithms, and schemas from the proposal.
The proposal (`proposal.md`) is authoritative; this is a convenience reference.
On conflict, the proposal wins.

**Proposal refs:** §5 (on-disk convention), §6 (resolution algorithm), §7 (verified
references), §8 (IR), §9 (CLI surface), §10 (phases).

---

## Anchor (`.mwp`) — TOML — proposal §5.1

The project root marker. Discovered by walking up from the target until found.
Fallback: `.git/`, then `--root` flag.

```toml
# .mwp  (workspace root)
name        = "myproject"
description = "Polyglot monorepo — Rust engine, TS backend, ViteJS frontend"

members = ["engine", "backend", "frontend", "packages"]

[budgets]
l0 = 800
l1 = 300
l2 = 500
l3 = 2000

[trust]
allowed_guards = ["cargo test", "npm run typecheck", "pnpm typecheck"]

[directories]
"engine"             = { role = "Rust processing core",           stack = ["rust"] }
"backend"            = { role = "Node.js/TypeScript API server",  stack = ["nodejs", "typescript"] }
"frontend"           = { role = "ViteJS/TypeScript frontend",     stack = ["vitejs", "typescript"] }
"packages"           = { role = "shared Node.js local modules",   stack = ["nodejs", "typescript"], shared = true }

[render]
window = 0   # 0 = full cascade; positive integer caps ancestor levels
```

**Sub-project root** (member with its own `.mwp`): minimal — `name`, `description`.
No `members`, no `directories`. `workspace:` imports resolve against the workspace
root (nearest ancestor `.mwp` with `members`).

**`directories` table:** Role descriptions for the L0 topology overview. `stack`
tags are open-ended hints for community module suggestions. `shared = true` signals
`mwp doctor` to warn if a member uses this directory without a `workspace:` import.

---

## Context files (`.mwp-context.yaml`) — YAML — proposal §5.2

> **Note:** Currently `.mwp-context.md` (YAML frontmatter + markdown body).
> Story 00 migrates to `.mwp-context.yaml` (pure YAML, body in `description` key).
> This spec shows the target format.

Optional at every directory level below root. Not used at project root (that space
belongs to `CLAUDE.md`, `.cursorrules`, etc.). When traversing the cascade, a
missing `.mwp-context.yaml` contributes nothing — it is a gap, not an error.

### Schema

```yaml
schema: 1               # required — must be 1
layer: 3                # L0–L4; mapper infers from depth if omitted
scope: recursive        # recursive (descendants inherit) | local (this dir only)
max_tokens: 1200        # overrides project budget if smaller
window: 2               # cap ancestor levels (0 = full cascade)
priority: 80            # tiebreaker within same layer (default 50)
description: |          # markdown body; optional — omit if nothing to describe
  # Purpose
  This module owns the browser-side SDK boundary.

  # Constraints
  No runtime reflection; prefer compile-time codegen.
imports:                # additional references spliced at this layer
  - local: ./rules.md
  - local: ./skills/rust.md
  - workspace: packages/shared-types
  - git: https://github.com/mwp-community/rust-idiomatic.git@v2.1.0
guards:                 # verified-reference checks (§7)
  - cmd: cargo test --lib
    cache_for: 10m
    trust: project
verified_paths:         # files whose change invalidates guard cache
  - src/api/
  - tests/smoke/
owners:                 # who maintains this context
  - team-backend
```

### Required vs. optional

| Key | Required | Default |
|-----|----------|---------|
| `schema` | **Yes** | — |
| `layer` | No | Inferred from depth |
| `scope` | No | `recursive` |
| `description` | No | — |
| `max_tokens` | No | Project budget |
| `window` | No | `0` |
| `priority` | No | `50` |
| `imports` | No | `[]` |
| `guards` | No | `[]` |
| `verified_paths` | No | `[]` |
| `owners` | No | `[]` |

### Rules

- **Extension:** `.mwp-context.yaml` (official), `.mwp-context.yml` (accepted alias).
  Mapper looks for `.yaml` first, falls back to `.yml`. Both in the same directory
  is an error.
- **No `../` in `local:` imports.** Ancestor context arrives via the cascade.
  Flagged by `mwp lint`.
- **`local:` path scope:** Only the declaring file's directory and subdirectories.
  No absolute paths.
- **`description`:** YAML literal block scalar (`|`). The markdown inside carries
  over unchanged — headings, lists, code spans, links.
- **`scope: local`:** Context applies only to the immediate directory, not
  descendants. Default `recursive` means children inherit.
- **Context granularity:** Keep files small (~2–8K tokens). If a file grows,
  split by concern and use `local:` imports to reference siblings.

### LLM instruction file boundary

`CLAUDE.md`, `.cursorrules`, `AGENTS.md` (and equivalents) mark a sub-application
boundary. When the mapper finds one, it stops descending and includes only the
directory's topology entry (name, path, role). It does not load the sub-project's
internal context. A directory with both `.mwp-context.yaml` and a `CLAUDE.md` is
a conflict — `mwp lint` warns.

---

## Module manifest (`.mwp-module.md`) — frontmatter + markdown — proposal §5.3

Identifies a directory as a community module. When resolving a `git:` or `local:`
import and `.mwp-module.md` is found, the mapper reads only what the manifest
lists. All `.mwp-context.yaml` files in the module's subdirectories are ignored.

```markdown
---
name: mwp-rust-idiomatic
version: 2.1.0
description: Idiomatic Rust — error handling, ownership patterns, async discipline
layer: 3
imports:
  - local: ./rules.md
  - local: ./perspective.md
  - local: ./craft/ownership-notes.md
  - local: ./craft/error-handling.md
  - local: ./craft/async-patterns.md
pipelines:
  - local: ./workflows/feature-impl.md
  - local: ./workflows/refactor-safety.md
---

Brief body describing what this module provides and who it is for.
```

**Rules:**
- Only files explicitly listed in `imports:` are included. Nothing is picked up by
  convention or directory scan.
- Module dependencies are declared via `git:` imports in the manifest. Each module
  pins its own versions (Deno-style — no shared lockfile).
- Module publishes as a Git repo tagged with a version. Consumers pin to tag or
  commit SHA.
- `CLAUDE.md` or equivalent at module root is ignored — the manifest is the single
  entry point.

---

## Import kinds — proposal §5.2–§5.3

Three kinds, distinct resolution rules:

| Kind | Path anchor | Use for |
|------|------------|---------|
| `local:` | Declaring file's directory | Files within the same sub-project |
| `workspace:` | `.mwp` directory (workspace root) | Sibling sub-projects in a monorepo |
| `git:` | Fetched into `.mwp/modules/<sha>/` | External community modules |

**`local:` rules:**
- `./rules.md` — same directory (✓)
- `./skills/rust.md` — subdirectory (✓)
- `./node_modules/@org/mwp-base` — subdirectory, installed package (✓)
- `../shared.md` — rejected (ancestor context arrives via cascade)
- `/abs/path` — rejected (no absolute paths)

**`workspace:` rules:**
- Path relative to the workspace root `.mwp`, not the declaring file.
- Must resolve within the workspace root (no escaping).
- When the sub-project runs standalone (no parent workspace), unresolvable
  `workspace:` imports are warnings, not errors.

**`git:` rules:**
- Must specify an immutable ref (tag or commit SHA). Floating refs (branch names)
  rejected unless `--allow-floating` is passed.
- Cloned into `.mwp/modules/<sha>/`. Treated as a `local:` import thereafter.
- Deduplication key: commit SHA.

### Deduplication

If the same resource appears in multiple cascade levels, it is included **once**
at the highest (closest to root) reference. Lower references are dropped and
recorded in the trace as `deduplicated_by: <higher_source>`.

---

## Cascade traversal algorithm — proposal §6

```
fn map(target, fresh=false):
    (sub_root, ws_root) = find_anchor(target)
    # sub_root: nearest .mwp walking up from target
    # ws_root:  nearest ancestor .mwp with members = [...], or sub_root if none
    # workspace: imports resolve against ws_root; cascade starts from ws_root
    files = traverse_cascade(ws_root, target)    # cheap: stat calls + path arithmetic

    if not fresh:
        key = content_hash(target, files)
        if cache_hit(key):
            return cache_read(key)

    layers = []
    for file in files:
        entry = parse(file)                   # YAML parsing + schema validation
        entry.imports = resolve_imports(entry)
        layers.push(assign_layer(entry))

    layers = deduplicate(layers)              # single include, closest-to-root wins
    layers = apply_budgets(layers, budgets)   # may drop/warn, never silently truncate
    layers = run_verifications(layers, mode)  # static | --verify | cached

    ir = IR(layers, trace)
    cache_write(key, ir)
    return ir
```

**Guarantees:**
- Root-to-leaf order in rendered output.
- Deterministic merge: entries at the same layer ordered by `(priority desc, path asc)`.
- Single include per resource (dedup before budget).
- Full trace: every entry carries `{ source_path, layer, reason, byte_range_in_output }`.

---

## Layer assignment — proposal §1.2, §5.2

| Layer | Role | Token target |
|-------|------|-------------|
| L0 | Project identity — what this is, stack, primary constraints | ~800 |
| L1 | Domain routing — which directory handles what, technology choices | ~300 |
| L2 | Module scope — public interface, responsibility, constraints of a directory | 200–500 |
| L3 | Reference — conventions, rules, patterns, skills | 500–2,000 |
| L4 | Executable constraints — guards and verification checks | variable |

Mapper infers layer from depth + filename when not declared in frontmatter. L0–L1
applies everywhere. L2–L4 applies within directory scope and all children. More
specific (closer to target) overrides less specific.

**Two-phase lensing (proposal §4, §8.1):**
1. **Orientation:** `map_workspace()` with no target → L0 topology + orientation preamble
2. **Lensing:** `map_workspace(target)` → focused cascade for the target file/directory

The orientation preamble embeds an instruction for the LLM to call `map_workspace(target)`
before beginning work — load-bearing for the two-phase model.

---

## Verified references (guards) — proposal §7

### Guard declaration

```yaml
guards:
  - cmd: cargo test --lib
    cache_for: 10m
    trust: project
```

### Execution modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| **Static** | Default | Reads cached results. No cache → marks `unverified`. |
| **Verify** | `--verify` | Runs all guards now; caches with TTL. |
| **Verify-only** | `mwp verify <target>` | Runs guards; emits report; no map. |

### Trust model

| Level | Scope | Approval |
|-------|-------|----------|
| `builtin` | `cargo test`, `npm run <script>`, `pnpm <script>`, `pytest`, `cargo clippy` | Always allowed |
| `project` | Listed in `.mwp` `trust.allowed_guards` | Allowed without prompt |
| `ad-hoc` | Anything else | CLI prompts on first run; MCP server refuses |

### Guard result

```json
{
  "guard": "cargo test --lib",
  "status": "passed",
  "exit_code": 0,
  "duration_ms": 3421,
  "ran_at": "2026-05-17T10:42:11Z",
  "cache_until": "2026-05-17T10:52:11Z",
  "fingerprint": "sha256:..."
}
```

### Fail-safe mode

When any guard is `failed`:
- Map is still produced but marked `read_only: true` in IR preamble.
- Renderer prepends a prominent warning block.
- Automated write actions (commits, deploys, code changes) must not proceed.
- Failure logged to `.mwp/discoveries.md`.

`stale` (TTL expired) causes a warning but does **not** engage fail-safe mode.

---

## IR schema — proposal §8

The stable contract. Every renderer and MCP tool returns this.

```jsonc
{
  "schema_version": "1",
  "target": "src/dev/feature-a/target.rs",
  "root": "/abs/path/to/project",
  "layers": {
    "l0": [ /* entries */ ],
    "l1": [ /* entries */ ],
    "l2": [ /* entries */ ],
    "l3": [ /* entries */ ],
    "l4": [ /* entries */ ]
  },
  "budgets": { "l0": 800, "l1": 300, "l2": 500, "l3": 2000 },
  "verifications": [ /* guard results */ ],
  "trace": [ /* one entry per included item */ ],
  "warnings": [ /* budget overruns, unresolved imports, floating refs */ ]
}
```

**Layer entry:**
```jsonc
{
  "source": "dev/.mwp-context.yaml",
  "layer": 1,
  "priority": 70,
  "tokens": 412,
  "scope": "recursive",
  "imports_chain": [],
  "body_markdown": "...",
  "guard_status": "passed" | "failed" | "stale" | "unverified" | null
}
```

---

## CLI surface (planned) — proposal §9

```bash
mwp init                              # scaffold .mwp + example .mwp-context.yaml
mwp map [target]                      # JSON IR (default)
mwp map [target] --render markdown    # pasteable markdown
mwp map [target] --render claude      # model-specific framing
mwp map [target] --session <id>       # incremental delta delivery
mwp explain <target>                  # human-readable trace
mwp lint                              # budget overruns, cyclic imports, floating refs
mwp verify <target>                   # run guards, write cache, emit report
mwp import <git-url-or-path>          # fetch and pin a remote module
mwp cache clean|status                # map cache management
mwp sessions list|inspect|rm|clean    # session management
mwp serve-mcp                         # stdio JSON-RPC MCP server
```

Universal flags: `--root <path>`, `--budget <layer>=<n>`, `--fresh`, `--session <id>`.

---

## Cache layout — proposal §5.4

```
.mwp/
├── .gitignore                  # tracks what to keep vs. ignore
├── topology.md                 # committed: workspace map (generated)
├── discoveries.md              # committed: session findings
├── intents/                    # committed (suggested): active task intent files
├── pipelines/                  # committed (suggested): promoted repeatable workflows
├── modules/<sha>/              # gitignored: pinned git module clones
├── guards.cache.json           # gitignored: guard results with TTLs
├── cache/<hash>.json           # gitignored: map cache keyed by content hash
└── sessions/<id>.json          # gitignored: session SeenSet + call log
```

**Map cache key:** SHA-256 of target path + content of every contributing file.
Staleness check on every `mwp map` call; re-traverse only when inputs changed.

**Guard cache:** Keyed by command string, invalidated by TTL expiry.

---

## Rendered output — proposal §8.1

Every rendered map begins with a generated preamble stating the contract:

**Focused preamble** (target specified):
```markdown
<!-- mwp workspace map | target: dev/browser-sdk/src/client.ts | schema: 1 -->

**How to use this map:** This map orients your work in this part of the project.
Source code is primary — use the map to understand the conventions and constraints,
then read and edit the actual files as needed. Rules listed here are constraints,
not suggestions. References marked ✓ have passed their verification checks.
References marked ⚠️ are flagged — their check is failing or stale; apply judgment.
```

**Orientation preamble** (no target — session start):
```markdown
<!-- mwp workspace map | target: (project root) | schema: 1 -->

**Project orientation map.** You have been given the high-level project overview,
not a focused file map. To proceed:

1. Read this map to understand the project structure and identify where the
   requested work belongs.
2. Call `map_workspace(target)` with the specific file or directory most relevant
   to the task.
3. Work from the focused map returned in step 2. Do not begin making changes
   from this orientation map alone.
```

---

## Intent and pipeline directories — proposal §5.5

- `.mwp/intents/` — active task intent files. One file per current task, named
  descriptively (`add-orders-view.md`). Listed in every map by path only; content
  loaded on demand.
- `.mwp/pipelines/` — promoted repeatable workflows. Listed in orientation map;
  content loaded on demand.
- Neither directory is required. `mwp init` scaffolds both with `.gitkeep`.
- `mwp doctor` warns when the same intent pattern repeats without a corresponding
  pipeline.
