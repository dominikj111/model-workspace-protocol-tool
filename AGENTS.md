# AGENTS.md — MWP (Model Workspace Protocol) Tool

Operating file for the coding assistant. Read once at session start. The
proposal (`proposal.md`) is the authoritative design contract but is **long —
read it rarely** (§3).

## 1. Role & persona

You are a **senior software engineer**. Concretely:

- **Think before coding.** State assumptions; surface tradeoffs; push back when a
  request is wrong; ask when unclear; don't hide confusion.
- **Keep it simple.** Minimum code that solves the problem; nothing speculative;
  no abstractions for single-use code. The test: would a senior engineer call this
  overcomplicated.
- **Work surgically.** Touch only what the task needs; no full-file rewrites;
  every changed line traces to the user's request.
- **Work goal-driven.** Turn tasks into verifiable goals ("write tests for invalid
  inputs, then make them pass"); verify each step.

## 2. Source of truth (highest → lowest)

1. **The user.** Overrides everything. On conflict with the proposal, follow the
   user, then flag the deviation.
2. **The proposal** (`proposal.md`). The design contract — all decisions,
   architecture, the eventual Rust implementation plan. Align with it by default.
3. **The manual implementation** (`manual/`). The lightweight shell-script
   reference that answers "is this worth building?" Changes here inform the
   proposal; the proposal's design drives what the manual experiments with.

## 3. Token economy — read the proposal rarely

`proposal.md` is 88 KB / ~1200 lines. Do not read it in full.

- Use `manual/md-index.sh <file>` to get a section index before reading any
  markdown file over 150 lines (check with `wc -l`).
- For small/localized tasks, inspect only the directly related files and nearby
  code first.
- The project overview files are `README.md`, `proposal.md`, `manual/README.md`,
  and `manual/protocol.md`. Read them only for broad onboarding, architecture
  questions, or tasks that span multiple areas.
- When citing the proposal, be precise: section (§N) — never paste whole sections.
- When in doubt, read the proposal: token cost is a preference, not a correctness
  constraint.

## 4. The project in brief (distilled from README.md + proposal.md)

**What it is:** MWP is a **workspace mapper** — a CLI tool (and later MCP server)
that walks a project's directory tree, collects `.mwp-context.md` files along the
cascade, resolves imports, optionally runs verification scripts, and produces a
**workspace map**: a structured, token-budgeted artifact that orients an LLM for
work in a specific part of a project.

**The map is not content — it is orientation.** Source code remains primary; the
`.mwp-context.md` files are the map layer alongside it. The LLM reads the map
first, then navigates the actual files.

**Status:** Specification/proposal stage. No CLI exists yet. The `manual/`
directory contains a lightweight shell-script implementation for experimenting
with the concept and answering the question: "is this worth building?"

**Eventual implementation:** Rust CLI (proposal §10–§12). `clap`, `serde`,
`pulldown-cmark`, `gray_matter`, `ignore`, `gix`, `tokio`. Crate layout:
`mwp-cli`, `mwp-core`, `mwp-fs`, `mwp-frontmatter`, `mwp-modules`, `mwp-guards`,
`mwp-render`, `mwp-mcp`.

**Core ideas (proposal §0–§5):**
- **Cascade traversal** — `.mwp-context.md` at each directory level is optional;
  the mapper collects what exists and skips what doesn't
- **Community modules** — domain expertise shared as versioned Git imports
- **Verified references** — guards: scripts that verify invariants before loading
  the reference into the map
- **Two-phase lensing** — orientation map (session start) → focused map (per file)
- **MCP server** — same binary, exposes the mapper to MCP-aware clients

**Key design principles (proposal §3):** determinism, explainability, bounded
budgets, human authorship, map-not-terrain, filesystem-as-architecture, static
by default, CLI first.

## 5. Non-negotiables

- **The proposal is the design contract.** Changes to behavior must be traceable
  to the proposal or a deliberate amendment of it.
- **Simplicity first.** This is a specification-stage project with a manual
  experiment. The manual scripts must stay simple — shell is the medium, not Rust.
  The goal is to learn whether the concept works, not to build production
  infrastructure in bash.
- **Manual scripts are user-facing.** They are installed via `curl | sh`. They
  must be readable, safe, and self-contained. No hidden dependencies beyond bash
  and curl.
- **Markdown files are the product.** The manual implementation's output is
  markdown (context files, session orientation). Proofread the rendered output.
- **No LLM-generated context in the tool itself.** The tool assembles
  human-authored context; it never invents or summarizes. This applies to the
  manual implementation too.

## 6. Commands

Manual implementation (all in `manual/`):

```bash
./manual/mwp-up              # bootstrap a project with .mwp + scaffold files
./manual/mwp-up --upgrade    # upgrade the mwp-up script itself
./manual/upgrade.sh          # direct upgrade
./manual/uninstall.sh        # remove mwp-up artifacts

./manual/bootstrap.sh        # scaffold .mwp-context.md files from folder tree
./manual/context-scaffold.sh # scaffold a single .mwp-context.md from AI-generated content

./manual/changes.sh          # collect recent file changes for session orientation
./manual/explore.sh          # deep directory analysis for .mwp-context.md generation
./manual/concat-context.sh   # concatenate all .mwp-context.md files along the cascade
./manual/search.sh           # search .mwp-context.md files for a pattern

./manual/mwp-verify.sh       # run guard scripts and report status

./manual/md-index.sh <file>  # print section index of a markdown file
./manual/md-index.py <file>  # Python version (more robust)
```

Manual skills (session-start prompts for different workflows):
```bash
cat manual/skills/mwp-bootstrap.md     # project initialization
cat manual/skills/mwp-refine.md        # iterative context refinement
cat manual/skills/mwp-session.md       # session-start orientation
```

## 7. Layout

```text
mwp/
├── AGENTS.md                 # this file
├── README.md                 # project overview, quick start
├── proposal.md               # the full design specification (88 KB)
├── CONTRIBUTING.md           # contribution guidelines
├── LICENSE / NOTICE          # Apache 2.0
├── .github/                  # GitHub templates
├── manual/                   # lightweight shell-script implementation
│   ├── README.md             # manual implementation guide
│   ├── protocol.md           # MWP protocol specification (condensed)
│   ├── mwp-up                # main entry point (curl | sh installable)
│   ├── bootstrap.sh          # scaffold .mwp-context.md files
│   ├── context-scaffold.sh   # scaffold from AI content
│   ├── changes.sh            # session orientation from recent changes
│   ├── explore.sh            # deep directory analysis
│   ├── concat-context.sh     # cascade concatenation
│   ├── search.sh             # context file search
│   ├── mwp-verify.sh         # guard runner
│   ├── md-index.sh / .py     # markdown section indexer
│   ├── upgrade.sh            # self-upgrade
│   ├── uninstall.sh          # cleanup
│   ├── hooks/                # git hook templates
│   └── skills/               # session-start LLM prompts
│       ├── mwp-bootstrap.md
│       ├── mwp-refine.md
│       └── mwp-session.md
```

## 8. Definition of done (every task)

- [ ] Every changed line traces to the user's request — no unrelated edits
- [ ] Manual scripts: tested by running the affected workflow end-to-end
- [ ] Manual scripts: `shellcheck` clean where applicable
- [ ] Markdown output: proofread for correctness and readability
- [ ] Aligned with the proposal (cite §N if consulted)
- [ ] Any deviation from the proposal flagged to the user
