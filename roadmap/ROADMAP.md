# MWP Roadmap

Implementation plan for the Model Workspace Protocol toolchain — manual experiment
through Rust CLI delivery. Story cards with statuses, verifiable acceptance criteria,
and proposal § refs. One story at a time.

Story statuses: ⬜ backlog / 🔄 in progress / ✅ done

---

## Step 0 — Format migration (manual + docs)

| ID  | Story                                      | Status | Handoff |
| --- | ------------------------------------------ | ------ | ------- |
| 00  | `.mwp-context.md` → `.mwp-context.yaml`    | ⬜      | [handoff](handoffs/01-mwp-context-yaml.md) |

**Goal:** Migrate the context file format from Markdown-with-YAML-frontmatter to
pure YAML. The markdown body moves into a `description` key. All existing
frontmatter keys carry over directly. A migration script converts existing
`.mwp-context.md` files and deletes the originals. All docs and manual scripts
updated to reference `.mwp-context.yaml`. This is the **breaking format change**
that must happen before any Rust implementation begins.

**Why now:** The `.mwp-context.md` format with YAML frontmatter is an awkward hybrid.
Pure YAML enforces structure, enables schema validation, keeps the format
consistent with `.mwp-module.md` frontmatter thinking, and forces developers to
think more structurally about their context. The migration is mechanical (frontmatter
is already YAML; the body just moves to a key), so the cost is low.

---

| ID  | Story                                                 | Status | Handoff |
| --- | ----------------------------------------------------- | ------ | ------- |
| 00a | Agent Skills: make discoverable by pi.dev/harnesses    | ⬜      | [handoff](handoffs/02-skills-discovery.md) |
| 00b | Extract format spec from proposal (`docs/format-spec.md`)  | ⬜      | — |
| 00c | Project boundaries: excerpt + soft re-anchoring             | ⬜      | — |

**Goal (00a):** The MWP skills ship in `manual/skills/` and `mwp-up` installs them to
`.mwp/skills/`, but neither path is in any harness's discovery list. Move installation
to `.agents/skills/mwp/` (standard cross-tool location), add cwd-assumption notes
to skill files, namespace names (`mwp-core`, `mwp-handoff`, `mwp-mapping`), and
document per-tool bridges in the post-install message.

**Goal (00b):** Extract normative format definitions, algorithms, and schemas
from the proposal into `docs/format-spec.md`. ~300 lines, no rationale — just
the implementation contract. States up front that the proposal is authoritative.
This is the quick-reference for manual script authors and the eventual Rust
developer. Will need a refresh pass after story 00 (`.mwp-context.yaml`
migration changes the context file format).

**Goal (00c):** Amend proposal §5.2 — boundary files (`AGENTS.md`,
`AGENTS.override.md`, `CONTEXT.md`, `CLAUDE.md`, `.cursorrules`) become soft
anchors. Parent map: leaf entries carry a short deterministic excerpt
(frontmatter `description:` else first paragraph, ≤ 5 lines — extraction, never
summarization). Focused map: a target inside a boundary directory re-anchors
the cascade there — no `mwp init` required; the boundary file is that map's L0
identity. Acceptance: parent map of a tree with nested projects shows each as a
leaf with excerpt and no internal context; `mwp map` targeting a file inside a
boundary directory produces a map rooted at that directory; `mwp lint` flags a
context file beside a boundary file; a materialised `AGENTS.md` (`mwp template`)
carries a `description:` frontmatter — `AGENTS.tpl.md` includes it so parent
maps show a useful excerpt. Reflect in `manual/protocol.md` and
`docs/format-spec.md`.

---

## Phase 1 — Minimum useful mapper (proposal §10)

**Goal:** Rust CLI that turns a folder tree into a rendered Markdown workspace map.

| ID  | Story                                                 | Status | Depends on |
| --- | ----------------------------------------------------- | ------ | ---------- |
| 01  | Project scaffold: Cargo workspace, crate layout       | ⬜      | 00         |
| 02  | `.mwp` anchor discovery with `.git` fallback           | ⬜      | 01         |
| 03  | Cascade traversal: collect `.mwp-context.yaml` files   | ⬜      | 02         |
| 04  | YAML parsing: schema validation, key extraction        | ⬜      | 03         |
| 05  | Naive token counter (whitespace-split for v1)          | ⬜      | 01         |
| 06  | Layer assignment (L0–L4) + budgeting                  | ⬜      | 04, 05     |
| 07  | JSON IR generation                                    | ⬜      | 06         |
| 08  | Markdown renderer with generated preamble              | ⬜      | 07         |
| 09  | `mwp map <target>` → JSON IR                          | ⬜      | 07         |
| 10  | `mwp map <target> --render markdown`                  | ⬜      | 08         |
| 11  | `mwp explain <target>` — trace output                 | ⬜      | 07         |
| 12  | `mwp lint` v1 — budget overruns, missing anchors       | ⬜      | 04         |

**Acceptance (Phase 1):** Author runs `mwp map dev/browser-sdk/phase-6/file.ts --render markdown`,
pastes into Claude, and the session is materially better-oriented than pasting the
file alone — without modules or guards. Cascade traversal does the work.

---

## Phase 2 — Imports and modules (proposal §10)

**Goal:** Resolve `local:` and `git:` imports, lay groundwork for the module ecosystem.

| ID  | Story                                                 | Status | Depends on |
| --- | ----------------------------------------------------- | ------ | ---------- |
| 13  | `local:` import resolution with cycle detection        | ⬜      | 07         |
| 14  | `git:` import resolution via `gix` (pinned refs only)  | ⬜      | 13         |
| 15  | `.mwp/modules/<sha>/` cache layout                     | ⬜      | 14         |
| 16  | Deduplication: single include, closest-to-root wins    | ⬜      | 13, 14     |
| 17  | `mwp import <git-url>` — pre-fetch and pin             | ⬜      | 14         |
| 18  | `mwp lint` v2 — cycles, unresolved imports, floating refs | ⬜   | 13, 14     |

**Acceptance (Phase 2):** A second project imports `github.com/<author>/mwp-rust-idiomatic@v0.1.0`
via one frontmatter line. The LLM session is oriented as an idiomatic Rust developer — correct
error handling conventions, no-unwrap policy, ownership patterns — without any of that
written inside the project itself.

---

## Phase 3 — Verified references and caching (proposal §10)

**Goal:** Guards, trust model, and map cache make the mapper qualitatively different from
"just walk the tree and concat."

| ID  | Story                                                 | Status | Depends on |
| --- | ----------------------------------------------------- | ------ | ---------- |
| 19  | Guard parsing: `guards:` + `verified_paths:` from YAML | ⬜      | 04         |
| 20  | Three execution modes: static / `--verify` / verify-only | ⬜   | 19         |
| 21  | Trust model: `builtin` + project allowlist + ad-hoc prompt | ⬜  | 20         |
| 22  | `.mwp/guards.cache.json` with TTLs and fingerprints    | ⬜      | 20         |
| 23  | Renderer surfaces guard status (✓ passed / ⚠️ failed)  | ⬜      | 08, 20     |
| 24  | Fail-safe mode: `read_only: true` when any guard fails | ⬜      | 23         |
| 25  | Map cache: content-hash-keyed IR in `.mwp/cache/`      | ⬜      | 07         |
| 26  | `mwp cache clean` / `mwp cache status`                 | ⬜      | 25         |
| 27  | `mwp verify <target>` — stage-suitable pass/fail report | ⬜     | 20         |

**Acceptance (Phase 3):** `mwp verify` run as a Git pre-commit hook catches a divergence
between `RULES.md` ("public methods return `Result`") and the codebase, and refuses the commit.

---

## Phase 4 — MCP wrapper (proposal §10)

**Goal:** Same binary, exposed as an MCP server for any MCP-aware client.

| ID  | Story                                                 | Status | Depends on |
| --- | ----------------------------------------------------- | ------ | ---------- |
| 28  | `mwp serve-mcp` — stdio JSON-RPC loop                  | ⬜      | 09         |
| 29  | MCP tool: `map_workspace(target?, render?)`            | ⬜      | 28         |
| 30  | MCP tool: `explain_context(target)`                    | ⬜      | 28, 11     |
| 31  | MCP tool: `verify_context(target)`                     | ⬜      | 28, 27     |
| 32  | Incremental delta delivery (per-connection SeenSet)    | ⬜      | 29         |
| 33  | MCP tool: `reset_session()`                            | ⬜      | 32         |
| 34  | `mwp sessions list/inspect/rm/clean`                   | ⬜      | 32         |
| 35  | Client config doc (Claude Code, Claude Desktop, Cursor) | ⬜      | 29         |

**Acceptance (Phase 4):** Claude Code, with `mwp serve-mcp` configured, fetches the right
context for the currently open file without the author pasting anything — and the trace is
identical to `mwp explain`.

---

## Phase 5 — Quality of life (ongoing, proposal §10)

Items individually small, prioritized by what the author hits while using the tool.

| ID  | Story                                                 | Status | Depends on |
| --- | ----------------------------------------------------- | ------ | ---------- |
| 36  | Per-model tokenizer (`tiktoken-rs`)                    | ⬜      | 05         |
| 37  | `mwp map --render {claude,gpt-4,llama}`               | ⬜      | 08, 36     |
| 38  | `mwp doctor` — health check on MWP setup               | ⬜      | 12         |
| 39  | `mwp publish` helper for community modules             | ⬜      | 17         |
| 40  | Windowed rendering (`window` field)                    | ⬜      | 03         |
| 41  | Workspace root + members support (monorepo)            | ⬜      | 02         |
| 42  | `.mwp-module.md` resolver + module manifest support    | ⬜      | 14         |
| 43  | `mwp-base` — the first community module                | ⬜      | 39, 42     |

Explicitly deferred: vector search, autonomous agents, LLM-driven summarization, registry hosting.
