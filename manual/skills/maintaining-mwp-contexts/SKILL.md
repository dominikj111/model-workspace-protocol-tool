---
name: maintaining-mwp-contexts
description: Use when meeting an unknown or foreign repository, module, or site; when working in a repository that carries MWP context files (.mwp-context.md / .mwp-context.yml) or boundary files (AGENTS.md, CONTEXT.md, CLAUDE.md, llms.txt); when a context file contradicts the code, sits at the wrong cascade level, or is missing where a directory has conventions worth stating.
---

# Maintaining MWP Context Files

## Overview

MWP context files are the map, not the terrain: labels and constraints that orient
an assistant without re-reading source. Living artifacts, revised as the code
evolves. The assistant may draft and edit; human review makes a file authoritative.

## When to Use

- Meeting an unknown or foreign repository, module, or site — orient from labels
  before exploring source; propose labels where none exist.
- Working in a repository that carries MWP context files or boundary files — work
  that invalidates a file updates it in the same change.
- A context file contradicts the code, is stale, or a convention sits at the wrong
  cascade level — fix it, elevate it, or push it down.

**When NOT to use:** reading only, no file affected, no labels missing — do not
touch context files; no speculative context gardening.

## Core Pattern

### 1. Labelling — meet an unknown system

1. Read the labels first: `.mwp-context.md` / `.mwp-context.yml` along the path,
   then boundary files (`AGENTS.md`, `AGENTS.override.md`, `CONTEXT.md`, `CLAUDE.md`,
   `.cursorrules`, `llms.txt`), then `README`.
2. Orient from them — what the directory is, owns, and must not do. Do not re-derive
   what a label already states.
3. If no label exists and the directory has conventions worth stating, **propose
   creating one** — a `.mwp-context.*` file below the boundary, or an `llms.txt` at
   a module root — so the system can be acknowledged without exploring all its
   source. Never create unasked: the proposal is the deliverable; human review is
   the gate.

### 2. Auto-edits — same change as the work

Mirror of the llms.txt contract: **if the code changes and the context file does
not, the change is incomplete.** When your work invalidates, extends, or contradicts
a context file the work concerns, update it in the same change — review, prune,
extend, adjust. Draft freely; nothing is authoritative until human review.

### 3. Propagation — keep the cascade lean

- **Elevate up:** a convention that helps every session graduates from a deep
  context file into the project's documentation, design contract, or root agent
  instruction file. Move it — do not copy it.
- **Push down:** a fact that turned out local moves into the directory's own context
  file.
- **Never duplicate** what a boundary file already states. A module root with a
  boundary file gets no `.mwp-context.*` beside it; the `.mwp/` directory is the
  home for module-local mwp tooling.

## Common Mistakes

| Excuse | Reality |
|---|---|
| "Context files are documentation, not my job" | The change is incomplete without them |
| "I'll update the context file later" | The next session reasons from a stale map |
| "I'll summarize what the code does" | Context is labels and constraints, never source summaries |
| "I'll copy the fact up and keep the original" | Elevation is a move; duplicates make the cascade fat |
| "Adding a label is harmless" | Creating labels unasked is scope creep — propose instead |
| "I noticed a stale file, I'll fix it while I'm here" | Surgical scope: only the files the current work concerns |

## Red Flags — STOP and re-read the rules

- "I'll update the context file in the next change"
- "The context file is stale but that's not my task"
- "I'll write a summary of the code here"
- "I'll add context files everywhere while I'm at it"
- "I'll place a context file next to the module's AGENTS.md"

**All of these mean: the context files the current work concerns are updated in the
same change — and nothing is authoritative until human review.**
