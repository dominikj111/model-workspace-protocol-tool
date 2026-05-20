# MWP — Model Workspace Protocol Toolchain

A comprehensive proposal for a deterministic workspace mapper, with a later MCP wrapper for direct LLM use.

- **Version:** 0.1
- **Status:** Foundational proposal
- **Authors / origin:** Dominik Jelinek, based on his blog post *"Your Folder Tree Is Already a Context Engine"* and the ICM-MWP paper notes (arXiv:2603.16021v1, Van Clief & McDermott, 2026)
- **Implementation target:** Rust CLI first, MCP server later (same binary)
- **Audience:** the author, future contributors, and any LLM that needs to understand what we are building and why

---

## 0. TL;DR

### The two workflows Van Clief describes

> **Read this first.** The paper describes two distinct workflows. This tool targets the first and accommodates the second. Confusing them leads to misunderstanding what the tool is for.

**Workflow A — Context structure (what this tool automates)**

Place a `CONTEXT.md` file in any directory that has conventions, constraints, or intent worth stating. The folder tree becomes a cascading context loader: working deep in a sub-project means every ancestor's context has already loaded, narrowing the LLM's focus layer by layer. No special tooling required — just markdown files in directories.

**Workflow B — Intent-driven pipeline (user discipline, not tool-enforced)**

Every task starts as a file (`intent.md` or a numbered stage file). The LLM processes it and writes an output file. The human reads, edits, and approves the output. The approved file becomes the sole input for the next stage. Nothing proceeds without the human explicitly promoting the file. The entire pipeline lives in the filesystem — resumable, auditable, and completely independent of chat session memory. No special tooling required here either.

**What this tool does**

This tool targets Workflow A. It automates the assembly of the context cascade, adds verified references, resolves community module imports, and produces a bounded, explainable workspace map. Workflow B is user discipline — the tool does not enforce it. But it accommodates it: intent files and promoted pipelines live in suggested, committed, scannable directories the mapper recognises and can include in the map.

---

Van Clief's Model Workspace Protocol is originally about structural project documentation — small, focused markdown files organized alongside the code, each describing one thing at one scope level: project identity, domain rules, stage contracts, reference material. That documentation layer is the raw material this tool works with.

This tool is a **workspace mapper**. Given a target (a file path or stage folder), it walks the project tree, reads the structural documentation layer — `.mwp-context.md`-class files along the cascade — parses their frontmatter, resolves imports from community modules, optionally runs verification scripts, and produces a **workspace map**: a structured, layered, bounded artifact that tells the LLM how to navigate and approach work in this part of the project.

The map is not content. A topographic map does not contain the mountain — it contains enough structured information about the mountain to reason about routes without walking every path. The workspace map does not contain the source code. It contains enough structured information about the codebase — conventions, constraints, intent, and verified invariants — that the LLM can orient itself and begin work without re-deriving all of that from scratch on every session. Source code remains primary. The markdown files are not a replacement for the code; they are the map layer that sits alongside it. The LLM reads the map first, then navigates the actual terrain as needed.

This proposal adds two things that Van Clief's original approach does not specify:

- **An abstraction layer**: the map is assembled deterministically from the file tree, with budgets, priorities, verified references, and an explainable trace — not assembled by hand each session.
- **A social mechanism**: community modules let practitioners share and compose domain-expertise maps — language idioms, deployment patterns, API conventions — the same way configuration presets are shared in software toolchains. This is infrastructure for distributing how to think about a technology domain, not just how to document a single project.

It is not a prompt framework, not an agent runtime, not a vector store, not a content extractor. It is a **workspace mapper**. Once the mapper is stable, it will be exposed through a thin MCP server so any MCP-aware LLM client (Claude Code, Claude Desktop, Cursor) can ask for the map for the current file and get the same deterministic artifact.

The non-obvious commitment: **the human stays the author of context.** The tool assembles and verifies; it never invents, never summarizes via LLM, never decides what your project means. Everything in the map traces to a file you wrote, an import you declared, or a verification you authorized.

---

## 1. Why this exists

### 1.1 The pattern we keep rediscovering

The author's path to structured AI-assisted development went through these stages — and the ICM-MWP paper's practitioner observations suggest the progression is recognisable beyond one person's experience:

1. Long, repeated prompts.
2. Pulling stable parts into reference files.
3. A `CLAUDE.md` (or equivalent) for always-true facts.
4. Per-task "agents" or sub-sessions.
5. Chaining agents — at which point the human silently drops out of the context-authoring role.

The blog post argues, and the ICM-MWP paper formalizes, that steps 2–3 were already the right direction. The folder tree is the natural home for context. A file like `dev/browser-sdk/phase-6/00_intent.md` already inherits everything its parent folders say — for free, by walking upward — the same way Node.js module resolution finds the closest `package.json`. The filesystem is already a cascading lookup engine; we just have to use it for context instead of code.

### 1.2 The five layers (from the paper)

| Layer | Role                                      | Token target |
| ----- | ----------------------------------------- | ------------ |
| L0    | Global identity (what is this project)    | ~800         |
| L1    | Routing (which folder / stage handles what) | ~300       |
| L2    | Stage contracts (input / process / output) | 200–500     |
| L3    | Reference material (voice, conventions, skills) | 500–2 000 |
| L4    | Working artifacts (current run)            | variable    |

> **Note on numbers.** The figures above are illustrative estimates drawn from the ICM-MWP paper and blog post. They represent rough working targets and order-of-magnitude expectations, not measured values. Real projects will land differently depending on project size, layer depth, and how much the author writes in each context file. The key point is the relative budget — L3 reference material should stay smaller than L0 global identity is wide, and the total orientation bundle should stay well below the "lost in the middle" threshold the paper associates with 40 k+ loads.

A focused stage loads 2–8 k tokens. A monolithic "load everything" approach exceeds 40 k and starts losing the middle. The folder tree gives us the layering for free; we only need a mapper that respects it.

### 1.3 The sixth category — verified references

This is the gap the blog post identifies and the paper does not have a slot for: in a software project, many references are also testable. A rule like "all public methods return `Result`" is encoded as prose in `rules.md` **and** as a test suite. Before loading the prose, we want to know the test still passes — otherwise the LLM reasons from a false premise.

We call these **verified references**. They are L3 references with an attached check (a test command, a sync-check script, a type-check). The mapper runs the check (or uses a recent cached result) and either includes the reference, marks it stale, or flags it so the LLM knows the invariant may not hold.

### 1.4 Distributing expertise — the module ecosystem

The cascade solves the per-project problem: context that belongs to a part of a project lives near that part and accumulates automatically. A second problem can emerge alongside it.

When context files encode knowledge about a technology stack — idiomatic patterns for a language, conventions for a framework, rules for a deployment platform — that knowledge is not inherently project-specific. It describes how to work well with the technology, independent of any particular product. Encoding it privately per project means it may drift across related projects, be rediscovered from scratch when a new project starts, and never benefit from broader review or correction. That same knowledge, published as a shared module and imported by version, becomes a stable, reviewable, evolvable artifact — independent of any single project.

The module import system (§5.3) is the mechanism. The vision it enables is this:

```yaml
# A project declares its technology stack once:
imports:
  - git: https://github.com/mwp-community/rust-idiomatic.git@v2.1.0
  - git: https://github.com/mwp-community/aws-cdk-serverless.git@v1.4.0
  - git: https://github.com/mwp-community/trpc-fullstack.git@v1.0.0
```

Each of those modules is a git repository containing a `.mwp-module.md` manifest that links to its content files — assembled by people who have spent serious time with that stack and have encoded what "thinking like a senior Rust developer" or "approaching this as a Cloud-Native AWS architect" actually means in practice. They may be published as Git repos, npm packages, or Cargo crates — the import mechanism is the same; the mapping step resolves them via their installed path.

The LLM that loads these modules is not a general-purpose assistant that happens to know Rust. For this session, it is a developer who thinks the way your team thinks — with idiomatic patterns, the anti-patterns flagged, the deployment model baked in, the constraint set established. No fine-tuning, no specialist agent, no context hand-off.

**This is the core of Van Clief's approach**: a well-layered, narrowing context hierarchy eliminates the need for multiple specialized agents. A multi-agent system routes queries to the right specialist, paying the cost of briefing and hand-off each time. A properly layered context system makes the single agent the right specialist — on demand, for the duration of the relevant work. The cost of "switching specialists" is loading a different module, not spinning up a new agent. The deeper the context hierarchy goes, the more precisely the LLM's focus is narrowed, until it operates as a domain expert for exactly the problem at hand.

A published module can also include the *output* of deep exploration — not just rules, but the distilled findings from examining a real codebase or ecosystem: common patterns, ownership-boundary reasoning, pitfall explanations. This is exploration done once, by someone who has done it, frozen as a high-confidence L3 reference. The mapper includes it; the LLM inherits the expert's perspective directly rather than re-deriving it from first principles in every session.

The pattern of sharing configuration as versioned packages already exists in some ecosystems: shared linting presets, compiler strictness configurations, commit convention rules. MWP modules propose the same class of artifact for AI orientation context — reusable, versioned, composable, independent of product code, and subject to the same review and update discipline as any shared configuration.

### 1.5 What goes wrong without a tool

Doing this by hand is possible — it is what the author currently does — but it has clear failure modes:

- **Token bloat** — naive concatenation of every parent `.mwp-context.md` quickly overshoots the 8 k sweet spot.
- **Drift** — references claim invariants that the codebase no longer satisfies. No one notices until the LLM produces confidently wrong output.
- **Reinvention** — orientation context that describes a technology stack or architectural approach tends to be written per-project, making it hard to share, review, or keep consistent across related work.
- **Opaque assembly** — when something goes wrong, there is no record of *why* a given snippet ended up in the prompt.
- **Manual `attention:` lists** — the human has to remember which references apply to which stage. As projects grow, this stops scaling.

A small, deterministic workspace mapper addresses all five.

---

## 2. Non-goals

To keep scope honest, the following are explicitly out:

- **Vector search / RAG / embeddings** as a primary resolution mechanism. Resolution is path-based and explainable.
- **LLM-generated context.** The tool never asks an LLM to summarize, infer, or rewrite your context files.
- **Agent orchestration.** No scheduling, no inter-agent messaging, no autonomous loops.
- **A new prompt-engineering DSL.** Frontmatter + Markdown. Nothing else.
- **A package registry of our own.** Sharing is via plain Git URLs, and modules may optionally also be published to npm, crates.io, or other registries — but the mapper never depends on a package manager to resolve imports. It resolves paths, nothing more.
- **Tight coupling to any single language ecosystem.** npm modules, Cargo crates, and Go modules are all welcome as *containers* for community context packages. The mapper treats them all as `local:` path imports after the package manager has installed them. It never drives the installation step itself.
- **Workflow enforcement.** The tool does not enforce how users interact with the produced map. Van Clief's staged pipeline pattern — `intent.md` → LLM processes → `output.md` → human review → next stage — is a valuable complement and is recommended, but it is user-managed. A project that adopts this discipline documents it in `.mwp-context.md`; the LLM, once oriented by the map, will naturally offer and guide the pattern. The tool has no mechanism to enforce it and deliberately avoids acquiring one.
- **LLM or IDE coupling.** The workspace map is plain text. It works with any LLM, in any IDE, on any OS. The MCP server (Phase 4) is a convenience for clients that support the protocol — not a requirement. A user who prefers to paste the map manually, pipe it to an API call, or use it with a local model has a complete workflow.

If any of these turn out to be valuable later, they are separate proposals.

---

## 3. Design principles

1. **Determinism.** Same inputs → same output. No probabilistic ranking inside the mapper.
2. **Explainability.** Every item in the map traces back to a file path, a rule, and a priority.
3. **Bounded budgets.** Every layer has a token cap. Exceeding it is an error the user resolves, not something the tool silently truncates.
4. **Human authorship.** The map is built from what the user wrote (or what someone else wrote and the user explicitly imported). The tool does not invent.
5. **Map, not terrain.** The output is a navigable map of the workspace, not a reproduction of it. Source code is primary; the markdown files are the map layer alongside it. The LLM reads the map, then explores the actual files as needed.
6. **Filesystem as architecture.** The tree is the spine. Frontmatter is the connective tissue. Code is a signal, not a source of truth for intent.
7. **Static by default, dynamic on request.** File reads are free; script execution requires explicit opt-in and is cached.
8. **CLI first, MCP second.** A useful CLI we can run in CI, IDEs, and shells must exist before we wrap it in any LLM protocol.
9. **.mwp-context.md is the extension interface.** New mapper capabilities are expressed as new .mwp-context.md frontmatter fields or new `.mwp` declarations. General capabilities belong in the core. Domain-specific capabilities belong in community modules. This division keeps the core small and lets the community grow the capability surface without forking the tool.
10. **Approach agnostic.** The tool produces a workspace map — a structured text artifact. What the user does with that map is their choice: paste it manually, load it via MCP, use it in any IDE, with any LLM. No MCP dependency, no Claude dependency, no IDE lock-in.

---

## 4. How the mapper works

The mapper produces a **workspace map** for a **target** (a file path or a stage folder):

```text
Target
  │
  ▼
1. Anchor discovery       (find .mwp / project root)
  │
  ▼
2. Cascade traversal       (root → ... → target's directory)
  │
  ▼
3. Frontmatter parsing     (yaml block + markdown body per file)
  │
  ▼
4. Import resolution       (local paths + git modules)
  │
  ▼
5. Layer assignment        (L0–L4 + verified-reference flag)
  │
  ▼
6. Budgeting & prioritization (token caps per layer)
  │
  ▼
7. Verification            (optional; runs / reads cached guard results)
  │
  ▼
8. Rendering               (JSON IR | Markdown | model-specific)
```

The LLM receives the map and uses it to orient its work — it knows the conventions, the constraints, the active invariants, and where to look. It then reads the actual project files as it needs to. The mapper is not in the loop between the LLM and the source files; it is in the loop before the LLM starts.

**Two-phase lensing.** Not every session starts with a known target file. A developer may open a session with a generic question — "propose a feature for X", "what should I work on next?", "how do I reinitialise this project?", "add an orders view to the dashboard" — without specifying any file. The LLM cannot receive a deep, file-specific map because there is no target yet to anchor on.

The intended interaction model has two phases:

1. **Orientation.** The session opens with `map_workspace()` called without a target — either automatically by the MCP client at session start, or manually by the user running `mwp map`. The mapper returns the project-level view: L0 topology, the directory overview, and the orientation preamble (see §8.1). This tells the LLM what the project is and where the work could plausibly live.

2. **Lensing.** Having read the orientation map, the LLM identifies which sub-project, directory, or file the query is about, then calls `map_workspace(target)` to fetch the focused map for that area. Only then does it begin working — from the deep, conventions-loaded, verified context for the actual target.

The instruction to perform step 2 must be embedded in the orientation map's preamble, because the LLM cannot know to follow this pattern unless the first map tells it to. A project with good .mwp-context.md coverage at each level makes lensing powerful: the LLM narrows from "this is a polyglot monorepo" → "this is the TypeScript backend" → "this is the orders API module" and by the time it reaches the work it has exactly the context that scope requires — without loading the Rust or ViteJS conventions that are irrelevant for the task.

Two passes — **traverse** then **render** — separated by a stable intermediate representation (IR). The IR is what the MCP server returns and what CI can diff.

### 4.1 A worked example

Project structure:

```text
project/
├── .mwp
├── CLAUDE.md                    ← project-level LLM instructions (not read by mwp)
├── dev/
│   ├── .mwp-context.md          ← L0: "browser SDK for EU logistics platform"
│   └── browser-sdk/
│       ├── .mwp-context.md      ← L1: "owns TS→Rust boundary; bundle < 50 KB compressed"
│       │   guards:
│       │     - cmd: ./bundle-size-check.sh
│       └── src/
│           └── client.ts   ← target
```

Without the map, the LLM opens `client.ts` and starts cold. It can read the file, infer from imports, but it does not know: this is a logistics platform, the bundle constraint exists, reflection is off the table, there is a tRPC type bridge to maintain.

Running `mwp map dev/browser-sdk/src/client.ts --render markdown` produces:

```markdown
<!-- mwp workspace map | target: dev/browser-sdk/src/client.ts | schema: 1 -->

**How to use this map:** This map orients your work in this part of the project.
Source code is primary — use the map to understand the conventions and constraints,
then read and edit the actual files as needed. Rules listed here are constraints,
not suggestions. References marked ✓ have passed their verification checks.
References marked ⚠️ are flagged — their check is failing or stale; apply judgment.

---

## L0 — Project identity
Browser SDK for the EU logistics platform. Primary interface for carrier
and shipper integrations.

## L1 — Module: browser-sdk
Owns the TypeScript → Rust API boundary.
Bundle size constraint: < 50 KB compressed.
Guard: bundle-size-check.sh — passed 8 min ago ✓
```

The LLM opens `client.ts` already knowing it is in a bundle-constrained, reflection-free tRPC boundary layer. The map told it. The source file did not change; what changed is that the LLM starts from the right position rather than guessing.

---

## 5. The on-disk convention

We adopt a small, explicit convention. Everything else is the user's choice.

### 5.1 Anchor

A project is rooted at a `.mwp` file. The same format serves two distinct roles depending on whether it is the nearest anchor or has a parent:

**Standalone project root** — the nearest `.mwp` walking up from the target. `workspace:` imports resolve relative to this file. Simple case: one project, one anchor, no nesting.

**Workspace root (monorepo)** — a `.mwp` that declares `members`. Each member is a sub-project that has its own `.mwp`. The mapper walks up from the target file twice: first to find the sub-project root (nearest `.mwp`), then to find the workspace root (nearest ancestor `.mwp` with `members`). `workspace:` imports resolve relative to the workspace root, not the sub-project root.

This mirrors the Cargo workspace / npm workspace model: each member is independently usable, and the workspace root is the meta-manifest that knows about all of them.

```toml
# .mwp  (workspace root — knows about all sub-projects)
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

# Folder topology: rendered at L0 as the project orientation overview.
# stack tags are open-ended; community modules respond to them.
# shared = true: mwp doctor warns if a member that uses this has no workspace: import.
[directories]
"engine"             = { role = "Rust processing core",           stack = ["rust"] }
"backend"            = { role = "Node.js/TypeScript API server",  stack = ["nodejs", "typescript"] }
"frontend"           = { role = "ViteJS/TypeScript frontend",     stack = ["vitejs", "typescript"] }
"packages"           = { role = "shared Node.js local modules",   stack = ["nodejs", "typescript"], shared = true }
"scripts"            = { role = "build and deployment scripts" }
"docker-compose.yml" = { role = "container orchestration" }

[render]
# 0 = full cascade (default). Positive integer caps ancestor levels.
# Root L0 identity is always included regardless of this setting.
window = 0
```

Each member has a minimal `.mwp` that makes it independently usable:

```toml
# engine/.mwp  (sub-project root)
name        = "engine"
description = "Rust processing core — shared event processing and HTTP API"
# No members, no directories — those live at the workspace root.
# stack-specific budgets or trust overrides can live here if needed.
```

```toml
# packages/.mwp  (shared modules — sub-project root)
name        = "shared-packages"
description = "Shared TypeScript types and utilities, consumed by backend and frontend"
```

**Standalone behaviour.** Running `mwp` from inside `engine/` alone — without the parent workspace present — produces a valid map anchored at `engine/.mwp`. In that context, `workspace:` imports are unavailable (there is no workspace root to resolve against) and the mapper reports a warning for any unresolvable `workspace:` reference, then continues with the remaining context. The sub-project degrades gracefully; it does not fail.

**External importability.** Because `packages/` has its own `.mwp`, it is a self-contained workspace. External projects can reference it as a `git:` import and receive its full context cascade — `.mwp-context.md` files, conventions, guards — without needing the monorepo root. This is the mechanism by which a shared-modules sub-project becomes a publishable community module without any manual packaging step.

Fallback chain when no `.mwp` is found anywhere in the walk: `.git/`, then explicit `--root` flag. We never guess based on `README.md` or top-level manifests — that fails in monorepos.

**Windowed rendering.** In a deep project tree the full cascade from root to a leaf file can accumulate more ancestor context than the task needs. The `window` field in `[render]` sets a global cap: `window = 3` means "include at most 3 ancestor levels above the target, plus L0 always." Per-directory .mwp-context.md can tighten this further:

```yaml
---
window: 2    # this directory and its children: cap ancestor inclusion at 2 levels
---
```

Default is `0` (full cascade) because the safe failure mode is too much context, not too little. Window narrowing is a performance optimization for projects where the full cascade is provably wider than useful.

### 5.2 Context files

**`.mwp-context.md` is used in subdirectories, not at the project root.** The root directory is owned by whatever LLM instruction file the toolchain requires — `CLAUDE.md` for Claude Code, `.cursorrules` for Cursor, `AGENTS.md` for others. The mapper reads neither file; they belong to the host tool, not to MWP. The only MWP artifact at the project root is `.mwp`. Below the root, `.mwp-context.md` is optional at every level: when traversing the cascade, the mapper checks for it at each directory; if none is present, that level contributes nothing and traversal continues. A project with no `.mwp-context.md` files below the root still produces a useful map from the `.mwp` topology alone.

This means adoption is incremental: start with just `.mwp`, add `.mwp-context.md` where a subdirectory has conventions worth stating, and grow coverage over time. A missing `.mwp-context.md` is a gap in enrichment, not an error.

`.mwp-context.md` is the **index file** for its directory's context when present — analogous to `index.js` / `index.ts` in a JavaScript module, `mod.rs` in Rust, or `__init__.py` in Python. When the mapper reaches a directory that has one, `.mwp-context.md` is the entry point: it defines the scope for that level, lists any additional files to include from the same directory or its subdirectories, and optionally imports external modules. Like a module index file, it can reference siblings and children — but not parents.

```markdown
---
layer: 3                    # L0 | L1 | L2 | L3 | L4 — defaults inferred from depth & filename
scope: recursive            # recursive (descendants inherit) | local (this dir only)
max_tokens: 1200            # overrides the project budget if smaller
window: 2                   # optional: cap ancestor levels included when this dir is in scope
imports:                    # additional references to splice in at this layer
  - local: ./rules.md                                    # sibling file — allowed
  - local: ./skills/rust.md                              # subdirectory — allowed
  - git: https://github.com/some-org/mwp-rust-conventions.git@v1.2.0  # external module — allowed
guards:                     # verified-reference checks (see §7)
  - cmd: cargo test --lib
    cache_for: 10m
    trust: project
priority: 80                # tiebreaker within the same layer (default 50)
---

# Purpose
This module owns the browser-side SDK boundary.

# Constraints
No runtime reflection; prefer compile-time codegen.
```

#### Import path rules

The cascade handles **vertical** relationships (ancestor → descendant) automatically. **Horizontal** relationships (sibling sub-projects) require an explicit import kind.

Three import kinds, each with a distinct resolution rule:

| Import kind | Path anchor | Use for |
| ----------- | ----------- | ------- |
| `local:` | declaring file's directory | files within the same sub-project |
| `workspace:` | `.mwp` directory | sibling sub-projects in a monorepo |
| `git:` | fetched into `.mwp/modules/` | external community modules |

`local:` path scoping:

| Path form | Allowed | Reason |
| --------- | ------- | ------ |
| `./rules.md` | ✓ | Same directory |
| `./skills/rust.md` | ✓ | Subdirectory |
| `./node_modules/@org/mwp-base` | ✓ | Subdirectory (installed package) |
| `../shared.md` | ✗ | Up the tree — cascade already delivers this |
| `/abs/path/to/file.md` | ✗ | Absolute path — not allowed |

`../` is never needed for ancestor context because the cascade delivers it for free. It is flagged by `mwp lint`. For cross-sibling references in a monorepo, `workspace:` is the correct mechanism — it makes the horizontal dependency explicit and anchors the path at the project root rather than the declaring file, which makes refactoring and tooling validation straightforward.

`.mwp-context.md` is the only reserved filename. Any additional files a team wants to include — rules, conventions, reference material — should be referenced from within `.mwp-context.md` using `local:` imports. There is no prescribed layout beyond the index file itself.

#### LLM instruction files as sub-application boundaries

`CLAUDE.md`, `.cursorrules`, `AGENTS.md`, and equivalent files mark a sub-application boundary during cascade traversal. When the mapper descends into a directory and finds one of these files, it stops and does not traverse deeper. The directory is added to the workspace map as a sub-application reference — topology-level only, exactly as `map_workspace()` without a target would present it: name, path, and declared role. Its internal conventions are not loaded into the current map.

This rule has two consequences:

- A sub-project that has `CLAUDE.md` but no `.mwp` is opaque to the parent map — and that is intentional. From the parent project's perspective, only the sub-project's basic role and interface matter. To work inside it, the sub-project must be initialised with `mwp init` first. Calling `map_workspace(target)` with a path inside an uninitialised sub-project exits with a message directing the user to run `mwp init` there — it does not produce a partial map.
- The mapper never needs to understand the semantics of these files. It treats their presence as a stop signal, nothing more.

`mwp lint` reports a warning when a directory has both a `.mwp-context.md` and a `CLAUDE.md` (or equivalent) — that combination is a conflict; the two are mutually exclusive at the same directory level.

### 5.3 Modules

Three import kinds, all deterministic:

- **`local:`** — a relative path to a directory or file within the declaring directory's subtree. Resolved at parse time. Cycles are an error.
- **`workspace:`** — a path relative to `.mwp`. Crosses sub-project boundaries within a monorepo. The path must resolve to within the workspace root — no escaping the project.
- **`git:`** — a Git URL with an immutable ref (tag or commit SHA). Cloned into `.mwp/modules/<sha>/` and treated as a local import from then on. A floating ref (a branch name) is rejected unless `--allow-floating` is passed.

No bespoke registry, no package manager dependency. Published npm or Cargo conventions can be imported via `local:` using their installed path within the subtree.

```yaml
# Import via git (language-agnostic, pinned, works in any project):
imports:
  - git: https://github.com/mwp-community/rust-idiomatic.git@v2.1.0

# Import from a sibling sub-project (monorepo, workspace-relative):
imports:
  - workspace: packages/shared-types   # path from .mwp, not from this file

# Import via installed npm package (within the current subtree):
imports:
  - local: ./node_modules/@org/mwp-conventions

# Import via installed Cargo crate convention path (within the current subtree):
imports:
  - local: ./vendor/mwp-rust-strict
```

#### Polyglot monorepos

The cascade handles vertical scope (root → sub-project → module) automatically. `workspace:` handles the horizontal dimension: one sub-project explicitly declaring that it depends on another's context.

A concrete example — Rust engine + TypeScript backend + ViteJS frontend + shared local packages:

```text
project/
├── .mwp                      # anchor; declares all sub-projects
├── CLAUDE.md                           # project-level LLM instructions (not read by mwp)
├── engine/                        # Rust processing core
│   └── .mwp-context.md                 # stack: rust; imports mwp-stack-rust-axum
├── backend/                       # Node.js/TypeScript API
│   └── .mwp-context.md                 # stack: nodejs+ts; imports packages/ context
├── frontend/                      # ViteJS/TypeScript UI
│   └── .mwp-context.md                 # stack: vitejs; imports packages/ context
├── packages/                      # shared local modules (shared = true in .mwp)
│   ├── .mwp-context.md                 # describes the shared type contracts and module boundaries
│   ├── shared-types/
│   └── shared-utils/
├── scripts/                       # build and deployment scripts
│   └── .mwp-context.md                 # optional: scripting conventions, tool assumptions
└── docker-compose.yml             # orchestration (declared in .mwp topology; no .mwp-context.md needed)
```

`backend/.mwp-context.md`:
```yaml
---
layer: 1
imports:
  - workspace: packages          # pull in shared type contract context
  - git: https://github.com/mwp-community/stack-nodejs-ts.git@v1.0.0
---
```

`frontend/.mwp-context.md`:
```yaml
---
layer: 1
imports:
  - workspace: packages          # same shared types — deduplication applies if root also imports
  - git: https://github.com/mwp-community/stack-vitejs.git@v1.0.0
---
```

When editing `backend/src/api/routes.ts`, the resolved cascade is:

1. Root `.mwp` topology — project identity and directory overview (L0)
2. `backend/.mwp-context.md` — backend conventions, with `packages/` context spliced in
3. `backend/src/api/.mwp-context.md` — if present (L2 stage contract or local rules)

The engine, frontend, and scripts contexts are not in scope — they are adjacent sub-projects, not ancestors. The LLM sees exactly the layers relevant to the backend API without loading the Rust stack or the ViteJS conventions.

The `docker-compose.yml` entry in `.mwp`'s `[directories]` table appears only in the L0 topology overview — it tells the LLM "this is how the sub-projects are wired together in development" without pulling orchestration detail into every file-level map.

**`shared = true` sub-projects** are a signal to `mwp doctor` that every sub-project that uses the shared directory should have an explicit `workspace:` import pointing to it. Missing imports are reported as warnings — not errors, because the decision to include shared context is always explicit, never injected.

#### Deduplication — single include, closest to root

If the same resource appears in multiple cascade levels — because two `.mwp-context.md` files both import the same git module, or both reference the same local file — it is included **once**, at the position of the highest (closest to root) reference. Lower references are silently dropped.

```text
project/
├── .mwp-context.md          imports: [git: mwp-rust-idiomatic@v2]   ← included here
└── dev/
    └── .mwp-context.md      imports: [git: mwp-rust-idiomatic@v2]   ← deduplicated, dropped
```

This is upward inheritance: a module declared at a higher scope applies to all scopes below it. Re-declaring it lower is redundant. The deduplication key is the resolved canonical resource — for `git:` imports, the commit SHA; for `local:` imports, the normalized absolute path.

#### Stack-classification community modules

A large and predictable module category: **stack modules** that encode the conventions of a particular technology. A directory declared as a Next.js frontend in `.mwp` has a predictable set of constraints — App Router file layout, React Server Component idioms, Tailwind usage patterns, fetch caching rules — that apply across every project using that stack. Those constraints don't belong in any single project's .mwp-context.md; they belong in a shared, versioned artifact the community maintains.

Stack modules are the answer:

| Module | Domain |
| ------ | ------ |
| `mwp-stack-nextjs` | Next.js App Router: RSC conventions, fetch patterns, Tailwind, image handling |
| `mwp-stack-django` | Django ORM, REST framework, migration discipline, test layout, settings split |
| `mwp-stack-laravel` | Eloquent, service/repository layer, Blade/Livewire, Artisan idioms, queue discipline |
| `mwp-stack-rust-axum` | Axum handler patterns, tower middleware, error types, tracing setup |
| `mwp-stack-*` | community-defined; the taxonomy is open |

The connection to folder topology: when `.mwp` declares `"packages/frontend" = { stack = ["nextjs"] }`, the mapper can surface a suggestion that `mwp-stack-nextjs` is a natural import for that directory's .mwp-context.md. The suggestion is advisory — the import is explicit in the .mwp-context.md, never injected automatically. A monorepo with a Next.js frontend and a Django backend imports each stack module at the right directory level; nothing bleeds across the boundary.

This is where the module ecosystem becomes qualitatively different from a collection of shared snippets. A practitioner who has worked deeply with Django REST framework encodes their knowledge once, publishes `mwp-stack-django`, and every project that imports it gets that perspective without the project author needing to rediscover the same patterns. The stack becomes the distribution unit for domain expertise.

#### What a well-formed community module contains

A module is identified by the presence of `.mwp-module.md` in its root directory — the same relationship as a `package.json` to an npm package. When the mapper resolves a `git:` or `local:` import and finds `.mwp-module.md`, it reads that file as the module manifest and ignores any `CLAUDE.md` or equivalent LLM instruction file in the same directory. Nothing else is loaded automatically — only what the manifest explicitly lists. All `.mwp-context.md` files in any subdirectory of the module are also ignored; a module is opaque except through its manifest.

`.mwp-module.md` declares module identity (`name`, `version`, `description`), context files to include via `local:` imports using whatever paths and names the author chose, pipeline templates to surface via a `pipelines:` list, and any module dependencies via `git:` imports. Each module is responsible for pinning its own dependency versions — Deno-style: no shared lockfile, each module owns its deps. File and folder names inside the module are unconstrained.

**Minimal module** — a git repo with just the marker file, contributing nothing yet:

```text
my-module/
└── .mwp-module.md    # presence marks this as a module; empty imports = no content contributed
```

**Typical module:**

```text
mwp-rust-idiomatic/
├── CLAUDE.md                    # human-facing docs — ignored by mwp inside a module dir
├── .mwp-module.md               # module manifest
├── rules.md                     # imported via local: in .mwp-module.md
├── perspective.md               # imported via local: — any name, author's choice
└── craft/                       # any directory name
    ├── ownership-notes.md       # imported via local:
    ├── error-handling.md        # imported via local:
    └── async-patterns.md        # imported via local:
```

**`.mwp-module.md` format:**

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

> **Future — global module cache.** Module dependencies declared in `.mwp-module.md` will eventually resolve against a global per-machine cache (analogous to Deno's module cache or Cargo's registry cache) rather than being re-fetched per project. This is not in scope for current phases but the import syntax is designed to be forward-compatible with it.

File names within a module are not constrained. Only files explicitly listed in `.mwp-module.md` are included — nothing is picked up by convention or directory scan.

A module is allowed to include pre-computed analysis — the distilled output of someone who has examined real codebases and ecosystem codepoints and frozen the findings as context. This is not speculation; it is expert knowledge encoded once and shared as a versioned artifact. When the collector includes the module, the LLM receives the expert's perspective directly.

Module authors are responsible for version discipline: breaking changes increment the major version; additive additions increment minor. Consumers pin to a tag or SHA. Drift between teams becomes a package update decision, not a manual reconciliation.

### 5.4 Cache layout

The `.mwp/` directory is the mapper's local storage. It mixes committed project data with generated and downloaded artefacts, so it carries its own `.mwp/.gitignore` to separate them.

**Commit to version control:**

- All `.mwp-context.md` files throughout the project tree — they encode the team's accumulated understanding and are as valuable as the code itself.
- `.mwp/topology.md` and `.mwp/discoveries.md` — project-specific maps built and refined over time.
- `.mwp/.gitignore` itself.
- `.mwp/intents/` — **suggested, not required** — active task intent files (Workflow B). One file per current task, written before the LLM begins work. The mapper scans this directory and includes any intent files in the workspace map when present. See §5.5.
- `.mwp/pipelines/` — **suggested, not required** — promoted, repeatable workflows (Workflow B). When a one-off intent proves worth repeating, the user moves or copies it here as a named pipeline template. The mapper scans this directory and surfaces available pipelines in the orientation map. See §5.5.

**Do not commit** (covered by `.mwp/.gitignore`):

```gitignore
# Downloaded/generated — re-created on demand
modules/
cache/
guards.cache.json
sessions/
*.sh
protocol.md
```

```text
.mwp/
├── .gitignore                  # tracks what to keep vs. ignore in this directory
├── topology.md                 # committed: workspace map generated by bootstrap
├── discoveries.md              # committed: session findings and decisions
├── intents/                   # committed (suggested): active task intent files
│   └── <task-name>.md         # one per current task; included in workspace map when present
├── pipelines/                 # committed (suggested): promoted repeatable workflows
│   └── <pipeline-name>.md     # abstracted from one-off intents; surfaced in orientation map
├── modules/                   # gitignored: pinned git module clones, keyed by commit SHA
│   └── <sha>/
├── guards.cache.json           # gitignored: guard execution results with TTLs (see §7)
├── cache/                     # gitignored: workspace map cache, keyed by content hash
│   └── <entry-hash>.json      # serialized IR for one target + input combination
└── sessions/                  # gitignored: named sessions for incremental delivery (see §8.1)
    └── <session-id>.json      # SeenSet + call log for one session
```

#### Two caching strategies, two invalidation models

| Cache | Keyed by | Invalidated by | Why |
| ----- | -------- | -------------- | --- |
| Guard results | command string | TTL expiry | Test execution is expensive; slightly stale is acceptable |
| Workspace map | content hash of all inputs | any contributing file changing | Map is a pure function of its inputs; TTL is wrong here |

#### Map cache key

The cache key for a given target is the SHA-256 of: the target path (normalized, relative to root) concatenated with the content of every file that contributed to the map — the cascade chain plus any resolved local imports. Pinned git modules are hashed once on fetch and their hash is stored alongside the module; subsequent map builds include the stored hash without re-reading the module files.

Computing the key requires the cascade traversal (to know which files contribute), but traversal is cheap: it is stat calls and path arithmetic. What the cache skips is frontmatter parsing, import graph resolution, layer assignment, budget enforcement, and rendering. On a warm cache, `mwp map` and the MCP `map_workspace` tool are near-instant.

#### Cache entries

Each entry is a JSON file containing the full IR plus metadata:

```jsonc
{
  "schema_version": "1",
  "target": "dev/browser-sdk/src/client.ts",
  "inputs_hash": "sha256:abc123...",
  "contributing_files": [
    ".mwp-context.md",
    "dev/.mwp-context.md",
    "dev/browser-sdk/.mwp-context.md"
  ],
  "created_at": "2026-05-17T11:30:00Z",
  "ir": { /* full IR */ }
}
```

The `contributing_files` list lets the mapper check staleness efficiently: re-hash those files, compare to `inputs_hash`. If equal, serve from cache. If different, re-traverse and overwrite the entry.

### 5.5 Intent and pipeline directories (Workflow B accommodation)

> **What these are.** Van Clief's Workflow B — intent-driven pipelines — is user discipline. The tool does not enforce it. These two directories are the tool's accommodation: suggested locations the mapper recognises and scans, so that users who adopt the pipeline pattern get it included in the map automatically. Neither directory is required. A project with neither works fully.

#### Consistent mapper behaviour for both directories

The mapper treats `.mwp/intents/` and `.mwp/pipelines/` the same way in every map: it lists the paths of files present in each directory, nothing more. The file names are the documentation — `add-orders-view.md`, `migrate-auth-tokens.md`, `release-checklist.md` are self-describing; the LLM reads the name and knows what the file is for. No additional prose documentation or wrapper files are needed.

The listing appears in every workspace map, not only in the orientation pass. This is intentional: a developer deep in `backend/src/api/routes.ts` should see that `add-orders-view.md` is an active intent, without having to return to a project-level view first. The paths are compact (one line per file), so the cost is negligible.

File content is **not** loaded into the map automatically. The LLM reads the name, decides whether it is relevant, and requests the file if needed. This avoids ballooning the map with the full text of multiple intent or pipeline documents — the naming convention carries the signal; the content is on demand.

#### `.mwp/intents/`

**Purpose:** Active task intent files. Before starting a non-trivial task, the user writes a short `<task-name>.md` describing what they intend to do and why. This is the starting file of a Workflow B pipeline for that task.

**Naming discipline:** The file name is the primary signal. Use a concise, action-oriented name that tells the LLM what the task is — `add-orders-view.md`, `migrate-auth-tokens.md`, `refactor-auth-middleware.md`. A name that requires the file to be read to understand what the task is defeats the purpose.

**Lifecycle:** The user creates the file before work begins, updates it as understanding evolves, and deletes or archives it when the task is done. The directory is committed — intent history is useful; it tells future sessions what was attempted and why.

#### `.mwp/pipelines/`

**Purpose:** Promoted, repeatable workflows. When a one-off intent proves worth repeating — a release checklist, a feature scaffolding sequence, a debugging runbook — the user moves or copies it here as a named pipeline template.

**Naming discipline:** Same principle: `release-checklist.md`, `feature-scaffold.md`, `db-migration.md`. The name tells the LLM what the pipeline is for; it reads the file only when the pipeline is relevant to the current task.

**Promotion signal:** `mwp doctor` warns when the same intent pattern appears more than once across archived intents without a corresponding pipeline — a nudge that abstraction may be warranted. The decision to promote remains the user's.

**Example layout:**
```text
.mwp/
├── intents/
│   ├── add-orders-view.md          # active: task started, in progress
│   └── migrate-auth-tokens.md      # active: separate task, parallel
└── pipelines/
    ├── feature-scaffold.md         # promoted: use this to start any new feature
    └── release-checklist.md        # promoted: always run before cutting a release
```

`mwp init` scaffolds both directories with a `.gitkeep` and a brief comment explaining their purpose. They appear in `mwp doctor` output when absent from a project that has been running for more than a few sessions — a gentle suggestion, not an error.

---

## 6. Resolution algorithm

```text
fn map(target, fresh=false):
    (sub_root, ws_root) = find_anchor(target)
    # sub_root: nearest .mwp walking up from target
    # ws_root:  nearest ancestor .mwp with members = [...], or sub_root if none
    # workspace: imports resolve against ws_root; cascade starts from ws_root
    files = traverse_cascade(ws_root, target)    # cheap: stat calls + path arithmetic

    if not fresh:
        key = content_hash(target, files)
        if cache_hit(key):
            return cache_read(key)            # fast path — skip everything below

    layers = []
    for file in files:
        entry = parse(file)                   # frontmatter + markdown body
        entry.imports = resolve_imports(entry)
        layers.push(assign_layer(entry))

    layers = deduplicate(layers)                      # single include, closest-to-root wins
    layers = apply_budgets(layers, project_budgets)   # may drop/warn, never silently truncate
    layers = run_verifications(layers, mode)          # static | --verify | cached

    ir = IR(layers, trace)
    cache_write(key, ir)
    return ir
```

Four properties this guarantees:

- **Root-to-leaf order.** Global identity loads first; specific constraints follow in the rendered output.
- **Deterministic merge.** Two entries at the same layer order by `(priority desc, path asc)`. There is no scoring step.
- **Single include per resource.** Deduplication runs before budgeting. The same module or file appears once at the highest scope that references it; all lower references are dropped and recorded in the trace as `deduplicated_by: <higher_source>`.
- **Full trace.** Every entry carries `{ source_path, layer, reason, byte_range_in_output }`. `mwp explain` simply pretty-prints this.

---

## 7. Verified references

This is the part that makes the tool useful for code, not just content pipelines.

### 7.1 Three execution modes

| Mode             | When                          | Behavior                                                                      |
| ---------------- | ----------------------------- | ----------------------------------------------------------------------------- |
| **Static**       | default (`mwp collect <t>`)   | Reads cached guard results. If no cache, marks reference as `unverified`.     |
| **Verify**       | `mwp collect <t> --verify`    | Runs all guards now; caches results with `cache_for` TTL.                     |
| **Verify-only**  | `mwp verify <t>`              | Runs guards; emits a report; does not produce a context bundle.               |

Why this matters: LLM clients call `collect` constantly. Running `cargo test` on every call is unacceptable. CI calls `verify` once before a stage; the result is cached for minutes; subsequent `collect` calls are instant and reflect a known-good check.

### 7.2 Trust model

Three trust levels for guards:

- **`builtin`** — a small set the tool ships with (`cargo test`, `npm run <script>`, `pnpm <script>`, `pytest`, `cargo clippy`). Always allowed.
- **`project`** — listed in `.mwp`'s `trust.allowed_guards`. Allowed without prompt.
- **`ad-hoc`** — anything else. The CLI prompts on first run, persists the decision in `.mwp/trust.lock`. The MCP server refuses ad-hoc guards entirely; only `builtin` and `project` run there.

The MCP server never grows a "trust this" tool. The author is responsible for promoting a guard from ad-hoc to project trust before the LLM can use it.

### 7.3 Result schema

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

A reference whose guard is `failed` or `stale` is included in the IR but **flagged**. The renderer surfaces this clearly — typically by wrapping the reference in a `> ⚠️ This reference's check is failing (cargo test exited 101)` callout, so the LLM has to actively decide whether to trust it.

---

## 8. Intermediate Representation (IR)

The IR is what every renderer and every MCP tool returns. It is the stable contract.

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
  "verifications": [ /* see §7.3 */ ],
  "trace": [ /* one entry per included item: source, reason, priority */ ],
  "warnings": [ /* budget overruns, unresolved imports, floating refs, ... */ ]
}
```

Each layer entry:

```jsonc
{
  "source": "dev/.mwp-context.md",
  "layer": 1,
  "priority": 70,
  "tokens": 412,
  "scope": "recursive",
  "imports_chain": [],
  "body_markdown": "...",
  "guard_status": "passed" | "failed" | "stale" | "unverified" | null
}
```

Renderers consume this IR; they never re-walk the filesystem. This is the single point of truth that makes MCP, CLI output, and CI checks consistent.

### 8.1 Rendered output format and the generated preamble

Every rendered Markdown map begins with a short generated preamble — produced by the renderer, not maintained by the user. It states the contract the LLM is expected to apply:

```markdown
<!-- mwp workspace map | target: dev/browser-sdk/src/client.ts | schema: 1 -->

**How to use this map:** This map orients your work in this part of the project.
Source code is primary — use the map to understand the conventions and constraints,
then read and edit the actual files as needed. Rules listed here are constraints,
not suggestions. References marked ✓ have passed their verification checks.
References marked ⚠️ are flagged — their check is failing or stale; apply judgment.

---
```

The preamble above is the **focused map preamble** — used when a specific target file is known. It covers three things: what this artifact is, what the LLM should do with it, and how to interpret the guard markers.

When `map_workspace()` is called without a target — at session start, before the user has named a file — the renderer produces the **orientation preamble** instead:

```markdown
<!-- mwp workspace map | target: (project root) | schema: 1 -->

**Project orientation map.** You have been given the high-level project overview,
not a focused file map. To proceed:

1. Read this map to understand the project structure and identify where the
   requested work belongs.
2. Call `map_workspace(target)` with the specific file or directory most relevant
   to the task — for example, the source file you intend to edit, or the
   sub-project folder the work lives in.
3. Work from the focused map returned in step 2. Do not begin making changes
   from this orientation map alone — it does not carry the deep conventions.

If you cannot identify a specific target from the task description, ask the
user to clarify which part of the project to focus on.

---
```

The orientation preamble is the mechanism that makes generic session-opening questions ("propose a feature", "what's next?", "add an orders view") work correctly. Without it the LLM might attempt to work from the project-level map alone, missing all the layer-3 conventions that only appear in the deeper cascade. The explicit instruction to call `map_workspace(target)` again is load-bearing: it converts "I have a project overview" into "I have identified the target and will fetch its focused context before acting."

The map does not need to be self-explanatory in isolation — it only needs to be self-explanatory given the preamble, and the preamble is always present. Layer sections (`## L0 — Project identity`, `## L3 — Module reference`) stay concise and content-focused without carrying meta-instructions.

For model-specific renders (`--render claude`, `--render gpt-4`), both preamble variants may be adjusted to match known model conventions, but the contracts they describe do not change.

#### Incremental delivery — MCP connection as session

In a multi-call session — orientation map followed by several targeted maps — each focused map would naively repeat the layers already in the LLM's context (L0 appears in every call; L1 for a sub-project appears in every call within that sub-project). This duplication is bounded in short sessions (L0 ≈ 800 tokens) but accumulates over longer ones.

**The MCP connection is the session.** When `mwp serve-mcp` starts, the client (Claude Code, Cursor, etc.) opens a stdio connection to the server process. That connection persists for the duration of the conversation — the server knows which connection each tool call came from. No session ID needs to pass through the LLM. No opaque token needs to be carried. The server maintains a per-connection `SeenSet` (a `HashMap<connection_id, Set<path:hash>>`) in memory and computes the delta on each call automatically.

```
connection opens
  → server allocates empty SeenSet for this connection

map_workspace()                         ← LLM passes nothing extra
  → SeenSet is empty → send full orientation map (L0)
  → SeenSet ← { ".:a1b2" }

map_workspace("backend/src/api/routes.ts")
  → SeenSet has ".:a1b2" → skip L0, send L1 backend + L2 api only
  → SeenSet ← { ".:a1b2", "backend:c3d4", "backend/src/api:e5f6" }

map_workspace("backend/src/orders/")
  → SeenSet has L0 + L1 backend → skip both, send L2 orders only
  → SeenSet ← { ..., "backend/src/orders:g7h8" }

connection closes
  → SeenSet discarded — no cleanup needed
```

The LLM is completely uninvolved in the deduplication concern. It calls `map_workspace(target)` exactly as it would without the delta mechanism; the server handles the rest.

The deduplication key is `normalized_absolute_path:content_hash`. Path is the stable identity (case-sensitive, as the filesystem returns it). Hash is the content fingerprint. If a `.mwp-context.md` changes mid-session, its hash changes and the updated content is delivered on the next call even if the old version is already in the LLM's context — the mechanism self-corrects without any LLM awareness.

**Sessions are first-class, not an MCP implementation detail.** A session is any string ID paired with a stored SeenSet. The MCP server auto-generates a UUID per connection; the CLI accepts `--session <id>` explicitly. Any caller — MCP connection, CLI invocation, test harness — can participate in a session. Sessions are stored on disk in `.mwp/sessions/<id>.json` (see §5.4) and are inspectable, listable, and deletable via `mwp sessions` subcommands.

Session record schema:
```json
{
  "id": "abc123",
  "created_at": "2026-05-18T10:00:00Z",
  "last_used": "2026-05-18T10:04:22Z",
  "seen": {
    ".": { "hash": "a1b2c3", "sent_at": "2026-05-18T10:00:00Z" },
    "backend": { "hash": "d4e5f6", "sent_at": "2026-05-18T10:02:11Z" }
  },
  "calls": [
    { "target": null,                        "layers_sent": ["L0"],        "layers_skipped": [] },
    { "target": "backend/src/api/routes.ts", "layers_sent": ["L1", "L2"], "layers_skipped": ["L0"] }
  ]
}
```

**MCP lifecycle.** For stdio MCP servers, Claude Code / Cursor typically spawns the process at session start and kills it at end — connection ≈ conversation. If a host keeps the server alive across conversations, state could bleed. The `reset_session()` tool clears the SeenSet for the current connection; the compaction recovery preamble instructs the LLM to call it if context seems inconsistent.

**Integration testing.** Because sessions are just named string IDs and stored on disk, the delta mechanism is fully testable without an MCP client or a running LLM:

```bash
mwp map --session test-delta-1                          # full orientation map; SeenSet ← { "." }
mwp map backend/src/api/routes.ts --session test-delta-1 # delta only; L0 not in output
mwp sessions inspect test-delta-1                       # assert SeenSet contains "." + "backend" + "backend/src/api"
```

The session ID is the test fixture. Tests are deterministic, reproducible, and self-describing.

**Phase note.** The delta mechanism is a Phase 4 optimization. Phase 1–3 accept full maps on every call — at bounded session lengths the extra tokens are affordable. The `--session` flag and `mwp sessions` commands are designed now so the API surface is stable when the implementation follows.

---

## 9. CLI surface (v1)

```bash
mwp init                              # scaffold .mwp + example .mwp-context.md at current dir
mwp map [target]                      # produce workspace map → JSON IR  (default --format=json)
mwp map [target] --render markdown    # rendered for direct paste into an LLM session
mwp map [target] --render claude      # model-specific framing
mwp map [target] --session <id>       # participate in a named session (delta delivery)
mwp explain <target>                  # human-readable trace: what loaded, from where, why
mwp lint                              # find: budget overruns, cyclic imports, floating refs, dead references
mwp verify  <target>                  # run guards, write cache, emit report
mwp import  <git-url-or-path>         # fetch and pin a remote module into .mwp/modules/
mwp cache   clean                     # remove all cached maps (not modules, not guards)
mwp cache   status                    # show cache size, entry count, oldest entry
mwp sessions list                     # list all stored sessions (id, created, last used, call count)
mwp sessions inspect <id>             # show SeenSet and call log for a session
mwp sessions rm      <id>             # delete a session
mwp sessions clean                    # remove sessions older than 7 days (configurable)
mwp serve-mcp                         # start the MCP server (Phase 4)
```

Universal flags: `--root <path>` to override anchor discovery, `--budget <layer>=<n>` to override token budgets, `--fresh` on any `mwp map` call to bypass the map cache, and `--session <id>` on any `mwp map` call to attach the invocation to a named session for incremental delta delivery.

---

## 10. Implementation roadmap

The phases are sized so each one ends with something the author can use that day. No phase depends on speculative future work in a later phase.

### Phase 1 — Minimum useful mapper (1–2 weeks)

**Goal:** turn a folder tree into a rendered Markdown workspace map.

Deliverables:

- `.mwp` discovery (with `.git` fallback).
- Root-to-leaf cascade traversal of `.mwp-context.md` only.
- YAML frontmatter parsing (`layer`, `scope`, `max_tokens`, `priority`).
- A naive token counter (whitespace-split is fine for v1; swap later).
- `mwp map <target>` → JSON IR.
- `mwp map <target> --render markdown` → pasteable Markdown workspace map.
- `mwp explain <target>` → trace.

Out of scope: imports, guards, MCP, modules, AST extraction, git history.

This phase is the foundation and must be boring and reliable before anything else is built on top.

### Phase 2 — Imports and modules (1 week)

- `imports: [local: ...]` resolution with cycle detection.
- `imports: [git: ...]` resolution using `gix` (pure-Rust git). Pinned refs only; floating refs rejected by default.
- `local:` path resolution also works for paths under `node_modules/` or `vendor/` — the mapper does not need to understand npm or Cargo, just a path.
- `.mwp/modules/<sha>/` cache layout.
- `mwp import <git-url>` to pre-fetch and pin.
- `mwp lint` v1 — flags cycles, unresolved imports, floating refs.

By the end of Phase 2 the author can publish `mwp-rust-idiomatic` as a Git repo, install it into a new project with one frontmatter line, and have the LLM immediately oriented as a Rust developer — without copying a single file into the project. This is the first step toward the community module ecosystem described in §1.4.

### Phase 3 — Verified references and caching (1–2 weeks)

- Frontmatter `guards: [...]` parsing.
- Three execution modes (static / `--verify` / `verify-only`).
- Trust model with `builtin` allowlist + `.mwp` `trust.allowed_guards` + interactive ad-hoc prompting.
- `.mwp/guards.cache.json` with TTLs and fingerprints.
- Renderer surfaces guard status in the output.
- `mwp verify <target>` produces a stage-suitable pass/fail report.
- **Map cache** (§5.4): content-hash-keyed IR cache in `.mwp/cache/`. Staleness check on every `mwp map` call; re-traverse only when inputs changed.
- `mwp cache clean` and `mwp cache status`.
- `--fresh` flag on `mwp map`.
- `.gitignore` template generated by `mwp init` covers `.mwp/cache/`, `.mwp/modules/`, `.mwp/guards.cache.json`.

This is where the tool starts to be qualitatively different from "just walk the tree and concat." The U-shaped intervention pattern from the paper becomes mechanizable: the map for a failing stage is flagged or refused until the author intervenes. And with the map cache in place, the MCP server (Phase 4) inherits near-instant repeat responses for free.

### Phase 4 — MCP wrapper (1 week)

- `mwp serve-mcp` — stdio JSON-RPC loop, same binary.
- MCP **resources**: `mwp://context/<path>` → the rendered Markdown bundle.
- MCP **tools**:
  - `map_workspace(target?, render?)` → workspace map as IR or rendered Markdown. When `target` is omitted, returns the project orientation map (L0 topology + orientation preamble). When `target` is given, returns the focused cascade for that path. In both cases the server automatically delivers only the delta relative to what has already been sent in this connection — the LLM passes nothing extra; session state is maintained server-side per MCP connection. See §8.1 for the incremental delivery protocol.
  - `reset_session()` → clears the server-side SeenSet for this connection, causing the next `map_workspace` call to return a full map. Use if context seems inconsistent after compaction or a conversation restart within the same connection.
  - `explain_context(target)` → trace.
  - `verify_context(target)` → guard report (only `builtin` + `project` trust; `ad-hoc` refused).
  - `list_targets()` → enumerates files with cascadable context, useful for IDE discovery.
- Hook up to Claude Code, Claude Desktop, Cursor; write a one-page client config doc.
- Recommended system prompt addition for MCP clients: `"At the start of every session, call map_workspace() with no target to load the project orientation. Follow its instructions to narrow to a focused target before beginning work."`

Critical invariant: the MCP server is a transport. **All resolution logic lives in the CLI core.** The MCP layer never reads the filesystem itself.

**Compaction recovery.** In a long session the LLM's context window may be compacted — Claude's `/compact` command or an equivalent in other clients trims earlier context to recover space. The workspace map, loaded at session start, can be trimmed out. When this happens the LLM loses orientation and may begin to drift: using conventions it no longer has in view, making assumptions that conflict with the project's rules. The recovery path is explicit: the LLM calls `map_workspace(target)` again. Because the result is deterministic and cache-keyed, the second call is near-instant — the resolver checks the content-hash, finds a hit, and returns the cached IR without re-traversing the filesystem. This round-trip is cheaper than reloading a long conversation and far cheaper than reasoning from incomplete context. A well-configured system prompt should include a standing instruction: "if you have lost the workspace map or are uncertain of the current constraints, call `map_workspace` before proceeding."

### Phase 5 — Quality of life (ongoing)

Items below are individually small and prioritized by whatever the author actually hits while using the tool:

- Better token counter (per-model tokenizer, e.g. `tiktoken-rs`).
- `mwp map --render {claude,gpt-4,llama}` with model-specific preamble framing.
- Smarter signal extractors (test adjacency, manifest hints, recent commits touching the target).
- `mwp doctor` — health check on a project's MWP setup.
- VS Code extension that calls the MCP server.
- A `mwp publish` helper that tags and pushes a Git module so others can `import` it by SHA.
- **`mwp-base`** — the first community module, published as a Git repo. Contains a `.mwp-module.md` manifest whose linked content files explain the MWP cascade convention itself: what each layer means, how to read the generated preamble, what a well-formed `.mwp-context.md` looks like. The content demonstrates the convention by being an instance of it — an LLM (or a new human contributor) that reads it understands the pattern without reading the spec. This is the onboarding artifact Van Clief's paper describes as the "generic root context file that explains the convention itself." As a published module, it becomes the natural base that other community modules extend.

Explicitly deferred: vector search, autonomous agents, LLM-driven summarization, registry hosting.

---

## 11. Repository layout

```text
mwp/
├── crates/
│   ├── mwp-cli/          # binary entry, clap, command wiring
│   ├── mwp-core/         # anchor, resolver, IR, budgets, trust  (no I/O leaks past this)
│   ├── mwp-fs/           # filesystem walking, file reads, ignore handling
│   ├── mwp-frontmatter/  # gray_matter wrapper, schema validation
│   ├── mwp-modules/      # local + git import resolution, cache layout
│   ├── mwp-guards/       # guard execution, trust model, cache
│   ├── mwp-render/       # IR → markdown / model-specific
│   └── mwp-mcp/          # MCP stdio server (Phase 4)
├── examples/             # tiny working projects per phase
├── specs/                # frontmatter schema, IR schema, JSON test fixtures
├── docs/                 # the proposal, the spec, the cookbook
└── tests/                # integration tests over examples/
```

Crate boundaries enforce the architectural invariant: `mwp-core` does not import `mwp-fs` types into its IR; the renderer does not call into the resolver; the MCP layer talks to the CLI core via the same public API a shell user does.

---

## 12. Technology choices

| Concern             | Choice              | Notes                                                              |
| ------------------- | ------------------- | ------------------------------------------------------------------ |
| Language            | Rust                | Single static binary, fast cold-start (matters for MCP), portable. |
| CLI parsing         | `clap` v4           | Standard.                                                          |
| Serialization       | `serde`, `serde_json`, `toml`, `serde_yaml` | Standard.                              |
| Markdown            | `pulldown-cmark`    | Streaming; we mostly pass bodies through verbatim.                 |
| Frontmatter         | `gray_matter`       | Battle-tested YAML-in-markdown extraction.                         |
| Filesystem walking  | `ignore`            | Respects `.gitignore` for free.                                    |
| Git operations      | `gix`               | Pure-Rust; no system `git` dependency in module fetches.           |
| Async runtime       | `tokio`             | Only where it earns its keep — MCP stdio loop, guard execution.    |
| Caching             | `moka`              | In-memory layer + on-disk JSON for guards.                         |
| Tokenization        | `tiktoken-rs`       | Phase 5; v1 ships with naive whitespace counting.                  |
| MCP                 | hand-rolled JSON-RPC over stdio initially; migrate to a Rust MCP SDK if the ecosystem stabilizes. |

No `node_modules`, no Python runtime, no Docker dependency. The tool must be installable as `cargo install mwp-cli` or a downloaded binary, with zero further setup.

---

## 13. Open questions

These are real, not rhetorical. Each one is something to revisit when implementation starts to bump into it.

1. **Token counting under disagreement.** Different models tokenize differently. v1 ships one counter and warns when the map is being rendered for a model whose tokenizer disagrees by more than a few percent. Is that acceptable?
2. **Recursive scope semantics.** Should `scope: recursive` apply to every descendant or only to descendants without their own same-named file? Current draft says "merge, not shadow" but real projects will surface the right answer.
3. **Guard output in IR.** Should guard `stdout` ever be embedded in the rendered context? Probably not by default — it could leak large blobs — but a `guards: [{ include_output_on_fail: true }]` flag may be worth it.
4. ~~**Stage progression.**~~ **Resolved — stays agnostic.** The tool does not enforce pipeline discipline. Van Clief's staged pattern (`<NN>_<stage>/` folders, `intent.md` → LLM → `output.md` → human review → next stage) is a recommended workflow users can adopt. A project that uses it declares it in `.mwp-context.md`; the LLM, once oriented by the map, will naturally offer pipeline-style guidance. No `next-stage` command will be added.
5. **Sharing model.** Pinned Git URLs work. They are not friendly to non-technical users. Whether and when to add a thin "named module" indirection (a `.mwp/registry.toml` that maps names to URLs) is open.
6. **Conflict between `imports` and the natural cascade.** If `dev/.mwp-context.md` imports a module that also defines a `RULES.md`, where does the imported file sit in the layer order? Current proposal: imports inherit the importing entry's layer and sort lower in priority. This needs real examples to validate.
8. **Nested workspace resolution edge cases.** The two-level anchor walk (sub-project root → workspace root) is clear for the common case. Three cases need resolution when implementation starts: (a) a sub-project's `workspace:` import references a member path that doesn't have its own `.mwp` — is that an error or does the mapper treat the directory as an implicit member? (b) a workspace root declares `members` but a `members` entry also declares `members` — does the mapper recurse, or is nesting capped at two levels? (c) `workspace:` imports when the sub-project is run standalone (no parent workspace) are currently reported as warnings and skipped — should the mapper try to fall back to a `git:` URL declared alongside the `workspace:` path as a resolution hint? This would let a .mwp-context.md express "use the local version if in the workspace, otherwise fetch from git."

9. **Semantic activation beyond path topology.** The current cascade is purely path-based: file location determines what context loads. A richer model would let modules declare activation signals — `activates_on: ["**/auth/**", "keyword:migration"]` — so the map responds to what the developer is actually doing, not just where the target file lives. This is the same mechanism Engram uses for node activation, applied one layer up: activating orientation context rather than solution paths. The activation rules would still be declared (not inferred), preserving determinism. Worth exploring in Phase 5 or later as a separate design. If implemented, the mapper starts to look less like a static cascade and more like a lightweight activation graph — a navigational graph that produces orientation rather than decisions.

---

## 14. What "done" looks like at each phase

To keep the project from drifting, each phase has a single concrete acceptance scenario:

- **Phase 1.** The author runs `mwp map dev/browser-sdk/phase-6/00_intent.md --render markdown`, pastes the map into Claude, and the session is materially better-oriented than pasting the file alone — without any modules or guards. The cascade traversal is doing the work.
- **Phase 2.** A second project imports `github.com/<author>/mwp-rust-idiomatic@v0.1.0` via one frontmatter line. The LLM session is oriented as an idiomatic Rust developer — correct error handling conventions, no-unwrap policy, ownership patterns — without any of that written inside the project itself.
- **Phase 3.** `mwp verify` run as a Git pre-commit hook catches a divergence between `RULES.md` ("public methods return `Result`") and the codebase, and refuses the commit.
- **Phase 4.** Claude Code, with `mwp serve-mcp` configured, fetches the right context for the currently open file without the author pasting anything — and the trace is identical to `mwp explain`.
- **Phase 5.** Someone other than the author starts a project with `mwp init`, imports two community modules, and gets a workable setup within an hour, without reading the spec.

The order is intentional: each scenario is the smallest thing that proves the phase's idea, and each one is independently useful. If we stop after Phase 1, we still have a tool worth using.

---

## 15. Relationship to Engram

[Engram](https://github.com/dominikj111/Engram) is a related project by the same author. The concerns are close enough that the distinction is worth establishing clearly.

### What Engram is

Engram is a deterministic reasoning kernel — a confidence-weighted directed graph that stores confirmed resolution patterns and serves as an operational layer for LLM workflows. Its documented deployment contexts include:

- **MCP knowledge database**: the LLM calls Engram as a tool mid-reasoning. Instead of a text chunk, it receives a typed reasoning path — confidence score, ruled-out candidates, resolved dimensions — and feeds confirmed answers back into the graph. Applicable in any MCP-aware client (Claude Code, Claude Desktop, Cursor).
- **LLM tool security boundary**: a policy engine sits between the LLM and the execution layer. Every action the LLM can trigger is explicitly enumerated in a contract file. Structural impossibility replaces prompt guardrails.
- **LLM agent mesh / cost optimizer**: a fleet of specialist graphs, one per domain, that handle bounded queries deterministically. The LLM is only engaged for genuinely novel cases; each resolution it confirms teaches the graph, shrinking the LLM's load over time. In a mature bounded domain, 70–80% of queries are projected to route through the graph without any model call (these are projections, not measured results — see Engram's own honest status section). This benefit applies to programmatic and automated-pipeline contexts; in an interactive chat session the user is the primary caller and there is no routing layer to intercept queries.
- **Team knowledge distillation, compliance routing, event-driven automation, embedded/offline diagnostics, technical debt mapping, and more** — see the full [use cases document](https://github.com/dominikj111/Engram/blob/main/docs/use_cases.md).

The core mechanic: nodes represent concepts and states; edges represent transitions with confidence weights. Confirmed outcomes strengthen paths; rejected or uncertain outcomes decay them. The graph learns from every session. What gets stored is the pattern — never the raw conversation, never attribution.

### What MWP is, by contrast

MWP is a deterministic orientation layer that assembles human-authored context before an LLM session starts. It does not act on queries, does not store outcomes, and does not learn. It reads the filesystem, collects and verifies the relevant context files, applies budget constraints, and hands off a structured orientation bundle. From that point it is out of the loop — the LLM navigates the project and produces its work.

### Comparison

| Dimension                | Engram                                       | MWP                                          |
| ------------------------ | -------------------------------------------- | -------------------------------------------- |
| Core artifact            | Weighted directed graph                      | Cascaded filesystem context files            |
| Source of truth          | Confirmed session outcomes (learned)         | Human-authored markdown (authored)           |
| When it acts             | At query / session time                      | Before the session starts                    |
| Does it learn?           | Yes — graph reinforcement from outcomes      | No — static collection from files            |
| LLM relationship         | Can substitute, preprocess, or be queried by LLM | Orients LLM before it begins work       |
| Determinism basis        | Graph structure + confidence thresholds      | File path + frontmatter + layer order        |
| Primary domain           | Repeated operational queries, bounded domains | Exploratory work, authoring, development   |

### One structural parallel

Engram's persona graphs (described in its future directions) are separable domain knowledge files — independently deployable, swappable, composable — elevated to a core architectural pattern for the specialist mesh. MWP modules (§5.3, §1.4) are the same concept at the orientation layer: independently authored, versioned, composable context packages that narrow the LLM's working focus to a specific technology domain. The mechanisms differ (confidence-weighted graph files vs. markdown cascades), but the compositional intent is the same.

### How they relate

Both tools move the LLM closer to the actual problem by narrowing its working surface — from different directions. MWP narrows the *input*: a bounded, layered, verified context cascade means the LLM starts each session already oriented rather than reconstructing context from scratch. Engram narrows the *operational layer*: typed reasoning paths replace re-derivation of known answers, a policy contract replaces brittle prompt guardrails, and persona graphs encode distilled domain expertise the LLM can draw on mid-session. Less overhead at the start; less overhead during the work; more focus on what is genuinely novel.

In a workflow that uses both: MWP handles the pre-session layer — the LLM knows the project's conventions, constraints, and domain before it begins. Engram handles the session layer — as an MCP tool it answers bounded operational queries with structured paths rather than model inference, and its policy engine enforces the action boundary when tool use is in play. Novel outcomes feed back into the graph. Neither requires the other. Both share the conviction that the LLM should not be the primary source of structure in a workflow.

### Engram vs. LangChain and AutoGen

LangChain and AutoGen are runtime orchestration frameworks — they coordinate tool calls, chain prompts, and route between agents. They solve a different problem from Engram: not *what the LLM knows*, but *how multiple LLM calls are sequenced and coordinated*.

The key differences:

- **LangChain** agents route decisions through the LLM at runtime — the model reasons each time about which tool to call and what to do next. Non-deterministic, no audit trail on the decisions themselves, re-derived every session. Engram handles the same class of bounded operational decisions deterministically, without a model call, and with a full path trace.
- **AutoGen** solves the "specialist knowledge" problem by spinning up separate briefed agents per domain, paying per-session briefing overhead and agent-to-agent handoff cost. It also has no structural policy boundary between agents and executable actions. Engram addresses both: one graph per domain (no briefing cost), and a contract file that enumerates every triggerable action (structural impossibility replaces prompt guardrails).

They compose naturally. A LangChain or AutoGen agent can call Engram as an MCP tool and receive a typed reasoning path — confidence score, ruled-out candidates, resolved dimensions — instead of re-deriving the answer from scratch. Engram reduces how much the orchestration layer needs to rely on the LLM for decisions it has already resolved. Neither replaces the other.
