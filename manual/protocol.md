---
version: "0.3.0"
---

# Workspace Mapping Protocol

**Document Structure:** Bootstrap (generates `topology.md`) → During the session (read map → load cascade once → navigate long files with `md-index.sh` → write to `discoveries.md`) → Context Verification (mwp-verify.sh) → Agentic Skills & Hooks → Creating .mwp-context.yaml files → Persistence rules → Five context layers.

Both files live in `.mwp/`. `topology.md` is regenerable. `discoveries.md` is permanent, human-curated accumulation.

---

## Agentic Skills & Hooks

The manual implementation includes skills and hooks to automate the protocol for AI agents:

- **Skills**: `.mwp/skills/` contains the instructions for the agent. If your agent supports skills, it should load this at the start of the session or they have to be registered in the config file (for example the crush.json).
- **Hooks**: `.mwp/hooks/mwp-guard.sh` is a verification hook that automatically runs `mwp-verify.sh` before write actions. This ensures the agent never modifies a read-only context.

---

## Bootstrap (once, or when topology changes)

Run from the project root:

```bash
bash .mwp/bootstrap.sh
```

Regenerate when: new sub-projects appear, manifests added or removed, major directories restructured.

---

## During the session

At session start:

1. Run `bash .mwp/changes.sh` — surfaces recent commits, uncommitted state, and whether `topology.md` is stale.
2. Read `.mwp/topology.md` — structural index of the project.
3. Read `.mwp/discoveries.md` — accumulated findings from previous sessions (may not exist yet).

When the target is known, follow this sequence **before doing any work**:

1. **Load the .mwp-context.yaml cascade — run this once per session, not per task.**

   ```bash
   bash .mwp/concat-context.sh <target-file-or-directory>
   ```

   This concatenates all context files from project root to the target in order.
   Per directory it uses `.mwp-context.yaml` → `.mwp-context.yml` → legacy
   `.mwp-context.md`; for YAML files only the `description` key is rendered (it
   holds the markdown prose — the other keys are metadata for the mapper).
   Running it more than once per session wastes tokens — the cascade is already in context.
   If the task has no clear target yet, ask the user to identify one before running it.

2. **Inject missing findings into `.mwp/discoveries.md`** — facts not yet recorded
   that were learned from the cascade or from reading source. Written now for future
   sessions; the current session already has them in context.

3. **Before automated write actions** (commits, deploys, code changes) — run the verifier:

   ```bash
   bash .mwp/mwp-verify.sh [target-directory]
   ```

   - Exit 0 (or "cache hit") → proceed normally.
   - Exit 1 → context is **read-only**. Inform the user, do not apply code changes or
     commits until the failing guards are resolved. The failure is logged to
     `.mwp/discoveries.md` and a diagnostics file under `.mwp/cache/`.

   The verifier is optional for read-only exploration sessions. Run it whenever the
   session will produce side effects.

4. **Proceed** — context is now enriched from topology, discoveries, and the cascade.

### Navigating long markdown files

**First, check the file size:** `wc -l <file>` (cheap — one command, one number).
Then apply:

Use `bash .mwp/md-index.sh <file>` to get a section table of contents before
reading large markdown files. Prefer `--format text` — it is ~60% cheaper in
tokens than the default YAML output and equally navigable.

It is **not always the right move** — there is a threshold where the TOC overhead
exceeds just reading the file:

| File size | Guidance |
|-----------|----------|
| **< 300 lines** | Read the whole file. The TOC overhead isn't worth it. |
| **300–800 lines** | Use `md-index` if you know the topic you need. Otherwise, just read it. |
| **> 800 lines** | Always use `md-index` first. Targeted reading is a clear win. |

The TOC hints (first ~120 chars of each section) may not carry enough context to
pick the right section. If you guess wrong and need a second targeted read, you
may be at or above the cost of reading the file from the start.

---

## Creating and Maintaining .mwp-context.yaml files

A `.mwp-context.yaml` is **not a session memory file** or a work log; it is a strictly **directory-descriptive document**. Think of it as a "mini-AGENTS.md" or "mini-CLAUDE.md" for a specific scope. It defines the terrain, constraints, and additional tooling (skills/hooks) available to any agent operating within that subdirectory.

A `.mwp-context.yaml` is a brief paragraph — a few sentences — describing what a directory owns,
its key constraints, and anything non-obvious. It is concatenated with siblings in the
cascade, so length directly costs tokens for every future session targeting that scope.
Keep it tight.

**AI/LLM Maintenance:** While primarily human-curated, AI assistants SHOULD propose updates or new `.mwp-context.yaml` files when they discover stable patterns, architectural decisions, or "surprises" that would benefit future sessions.

While exploring, watch for directories where a `.mwp-context.yaml` would add lasting value.
Good candidates:

- sub-project or package root with its own manifest
- module with a clear, bounded responsibility
- utility or shared folder used widely across the project
- any directory whose constraints would surprise someone opening it cold

Do **not** create one per folder — only where the scope is meaningful and the content
would be non-trivial to derive from the code alone.

### Workflow for Context Files

Before creating or significantly updating a `.mwp-context.yaml`, ask the user targeted questions. Tell them explicitly that the questions are prompted by the MWP protocol to ensure accuracy rather than inference. Good questions:

- What does this directory own and what is outside its scope?
- Are there hard constraints (size budgets, forbidden patterns, required return types)?
- What stack or tooling decisions apply specifically here?
- What would surprise a developer opening this directory for the first time?

**Action:** Use `bash .mwp/context-scaffold.sh <dir>` to create a new stub, then replace the comments with the brief paragraph. The stub is pure YAML (`schema: 1` + TODO comments) — the paragraph goes into the `description:` key. The `description` is human-authored markdown prose, and it may become the boundary `AGENTS.md` when the directory is extracted into a standalone project or repository — write it as self-contained, readable markdown, never as data.

---

## Persistence rules

Write to `discoveries.md`:

- `stack:` — observed language, framework, runtime
- `boundary:` — what this sub-project owns and does not own
- `convention:` — coding or architectural rules in force
- `dependency:` — explicit cross-sub-project relationships
- `constraint:` — hard limits (size, performance, security, compliance)
- `skills:` — custom agentic skills available in this scope
- `owner:` — team or person responsible

Suffix `?` on any item inferred rather than directly observed:

```markdown
- stack: Node.js, TypeScript
- stack?: tRPC  (inferred from ./backend/package.json dependency)
- boundary: owns HTTP API layer, no direct browser access
- skills: use .mwp/skills/mwp/SKILL.md for the session protocol
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
`.mwp-context.yaml` at a directory boundary (where `.mwp/` exists) stops upward traversal.
`AGENTS.md`, `AGENTS.override.md`, `CONTEXT.md`, `CLAUDE.md`, `.cursorrules` (and equivalents)
stop **downward** traversal: a directory carrying one is a project boundary. From the parent
map it appears as a leaf entry — name, path, and a short deterministic excerpt (frontmatter
`description:` or the first non-heading paragraph, ≤ 5 lines; extraction, never a summary).
When the target lies inside such a directory, the boundary file re-anchors the map: the
cascade starts there and descends to the target, with the boundary file as that map's L0
identity — no `mwp init` required. This is how the mapper distinguishes project A from
project B inside a shared tree: each boundary file is a nested root; `.mwp/` remains the
hard anchor above them.

---

## Notes

**Skills and Hooks** are manual-implementation extensions that automate MWP compliance for agentic sessions. They use `.mwp/skills/` and `.mwp/hooks/` to bridge the gap between static docs and active enforcement.

**`topology.md` and `discoveries.md`** are committed project data introduced by this manual
implementation, and they stay committed in `.mwp/` when the tool ships (proposal §5.4). What
changes is the generator: `topology.md` is produced by the tool's deterministic map output
instead of `bootstrap.sh`. `discoveries.md` remains human-accumulated findings that the tool
cannot derive automatically.

**Community modules** (`imports: [git: ...]` in .mwp-context.yaml) are a mwp-tool
feature. They are not available in this manual implementation.

**`.mwp/` is the anchor — a directory, not a file.** The manual and the future mwp-tool agree here (proposal §5.1, §5.4): a project is rooted at a `.mwp/` directory whose presence marks the cascade boundary (see "Five context layers"). The anchor config lives at `.mwp/config.toml` (`name`, `members`, `budgets`, `trust`, `directories`, `render` window) — there is no bare `.mwp` file. The directory is a single namespace for everything: committed project data (`topology.md`, `discoveries.md`, skills, hooks, scripts, `intents/`, `pipelines/`) plus generated map and module caches. The manual's shell scripts are superseded by CLI commands (`bootstrap.sh` → `mwp init`, `concat-context.sh` → `mwp map`, `mwp-verify.sh` → `mwp verify`); data carries over. Auto-migration handles the transition.
