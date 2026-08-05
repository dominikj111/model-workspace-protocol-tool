# Handoff: `.mwp-context.md` → `.mwp-context.yaml`

**Story ID:** 00  
**Status:** ⬜ backlog  
**Depends on:** nothing  
**Proposal refs:** §5.2 (context files), §5.3 (modules), §8 (IR)

---

## Why

The current `.mwp-context.md` format is an awkward hybrid: YAML frontmatter
(between `---` markers) bolted onto a free-form markdown body. Pure YAML:

- **Enforces structure.** Every key is explicit; no ambiguity about what is
  metadata vs. prose.
- **Enables schema validation.** We can reject malformed files at parse time
  rather than silently loading partial context.
- **Keeps format consistency.** `.mwp` (TOML) is structured; `.mwp-module.md`
  frontmatter is structured; `.mwp-context.yaml` completes the set.
- **Encourages discipline.** A structured file nudges authors toward thinking in
  terms of `layer`, `scope`, `imports`, `guards` rather than dumping everything
  into free-form prose.
- **Migration is mechanical.** The frontmatter block is already valid YAML. The
  markdown body just needs to move into a `description` key. No information is
  lost.

This is a **breaking change** — `.mwp-context.md` is not supported after
migration. A migration script handles all existing files.

---

## The new format

### Extension

- **Official:** `.mwp-context.yaml`
- **Accepted alias:** `.mwp-context.yml`
- The mapper looks for `.mwp-context.yaml` first, falls back to `.mwp-context.yml`.
  Both are never present in the same directory (that's an error).

### Schema

```yaml
# .mwp-context.yaml — minimal valid file
schema: 1
layer: 1
scope: recursive
```

```yaml
# .mwp-context.yaml — full example
schema: 1
layer: 3
scope: recursive
max_tokens: 1200
window: 2
priority: 80
description: |
  # Purpose
  This module owns the browser-side SDK boundary.

  # Constraints
  No runtime reflection; prefer compile-time codegen.

  # References
  See ./API.md for the public surface contract.
imports:
  - local: ./rules.md
  - local: ./skills/rust.md
  - git: https://github.com/mwp-community/rust-idiomatic.git@v2.1.0
  - workspace: packages/shared-types
guards:
  - cmd: cargo test --lib
    cache_for: 10m
    trust: project
verified_paths:
  - src/api/
  - tests/smoke/
owners:
  - team-backend
```

### Key changes from old format

| Old (`.mwp-context.md`)                           | New (`.mwp-context.yaml`)                  |
| ------------------------------------------------- | ------------------------------------------ |
| YAML between `---` markers, then markdown body    | Pure YAML; body in `description` key       |
| No schema version                                 | `schema: 1` required                       |
| `---` markers delimiting frontmatter              | No markers — the file is the YAML document |
| `<!-- MWP CONTEXT ... -->` HTML comment stubs     | Stub is minimal YAML with `description:`   |

### `description` key design

- **Key name:** `description` (not `text`, `body`, or `content`). It describes the
  directory's purpose, constraints, and non-obvious facts.
- **Value:** A YAML literal block scalar (`|`) preserving markdown formatting. The
  markdown syntax (headings, lists, code spans, links) carries over unchanged.
- **Optional.** A directory with nothing to describe beyond what the structured
  keys already say can omit `description` entirely. Example: a leaf directory
  that only needs `layer: 2` and a guard.
- **One block, not per-section keys.** The user's instruction is to move the
  markdown body into a single key. We do not break it into structured
  sub-keys (no `purpose:`, `constraints:`, `references:` at the YAML level).
  Those remain markdown headings inside `description:`.

### Required vs. optional keys

| Key              | Required | Default           | Notes                                    |
| ---------------- | -------- | ----------------- | ---------------------------------------- |
| `schema`         | **Yes**  | —                 | Must be `1`                              |
| `layer`          | No       | Inferred from depth | L0–L4; mapper infers if omitted        |
| `scope`          | No       | `recursive`       | `recursive` or `local`                   |
| `description`    | No       | —                 | Markdown prose (literal block scalar)    |
| `max_tokens`     | No       | Project budget    | Override per-directory                   |
| `window`         | No       | `0` (full cascade)| Cap ancestor levels                      |
| `priority`       | No       | `50`              | Tiebreaker within same layer             |
| `imports`        | No       | `[]`              | `local:`, `workspace:`, `git:` entries   |
| `guards`         | No       | `[]`              | Verified-reference checks                |
| `verified_paths` | No       | `[]`              | Files whose change invalidates guard cache |
| `owners`         | No       | `[]`              | Who maintains this context               |

---

## Migration script

### What it does

1. Finds all `.mwp-context.md` files in the project tree (respecting `.mwpignore`).
2. For each file:
   a. Extracts the YAML frontmatter (content between first two `---` markers).
   b. Extracts the markdown body (everything after the closing `---`).
   c. Strips leading/trailing whitespace from the body.
   d. If the body is non-empty and not just an HTML comment stub, sets it as
      the `description` key (literal block scalar).
   e. Adds `schema: 1` at the top.
   f. Writes the result to `<same-path>/.mwp-context.yaml`.
   g. If the YAML is valid and the output file was written successfully,
      deletes the original `.mwp-context.md`.
3. Reports: count of migrated files, any errors, any files that were skipped
   (already have a `.yaml` sibling, or `.md` was unparseable).

### Script location

`manual/migrate-to-yaml.sh` — shipped alongside the other manual scripts.
Distributed via `mwp-up` like the others.

### Edge cases

| Case                                          | Behaviour                                              |
| --------------------------------------------- | ------------------------------------------------------ |
| No frontmatter (file doesn't start with `---`)| Skip with warning; the file is not valid MWP context   |
| Empty frontmatter (just `---\n---`)            | Treated as no keys; only `schema: 1` set               |
| Body is only the HTML comment stub             | `description` omitted (it's the scaffold placeholder)   |
| Body is only whitespace                       | `description` omitted                                   |
| `.mwp-context.yaml` already exists alongside   | Skip the `.md` file; warn about conflict                |
| YAML frontmatter contains tabs                | Convert to spaces before writing (YAML spec requires spaces) |
| Body contains `---` sequences                 | Only the first pair of `---` is treated as frontmatter delimiters |

---

## Two outcomes

### Outcome 1 — Docs updated (every `.mwp-context.md` reference)

Files to update:

| File                | Count of references | Notes                                       |
| ------------------- | ------------------- | ------------------------------------------- |
| `proposal.md`       | ~46                 | Largest change. Most are inline path refs.  |
| `README.md`         | ~4                  | Project overview references.                |
| `AGENTS.md`         | ~9                  | Commands, layout, project-in-brief.         |
| `manual/README.md`  | ~9                  | Manual implementation guide.                |
| `manual/protocol.md`| ~11                 | Protocol specification (condensed).         |
| `manual/skills/mwp/SKILL.md` | ~2          | Session-start prompt.                       |

**Strategy for `proposal.md`:** Search-and-replace `.mwp-context.md` →
`.mwp-context.yaml` throughout. There are ~46 instances; most are mechanical.
Six require prose adjustment:

1. **§5.2 paragraph 1** — The sentence "`.mwp-context.md` is the **index file**
   for its directory's context" needs rewriting to describe the YAML format.
2. **§5.2 "Context granularity"** — The example tree shows `.mwp-context.md`
   split into `.mwp-context.api.md` / `.mwp-context.testing.md`. These become
   `imports:` entries referencing `.mwp-context.api.yaml` etc.
3. **§9.0 frontmatter block** — The code example showing YAML frontmatter in a
   markdown code block should be replaced with the pure-YAML example.
4. **§5.3 "What a well-formed community module contains"** — Reference to
   `.mwp-context.md` files in module subdirectories being ignored.
5. **§5.4 "Commit to version control"** — Bullet about committing
   `.mwp-context.md` files.
6. **§8.1 "Incremental delivery"** — Reference to `.mwp-context.md` changing
   mid-session.

**Strategy for other docs:** Mechanical search-and-replace, plus updating any
code blocks that show the old format.

### Outcome 2 — Manual scripts updated

Scripts to update:

| Script                  | What changes                                          |
| ----------------------- | ----------------------------------------------------- |
| `bootstrap.sh`          | Find `.mwp-context.yaml` instead of `.mwp-context.md` |
| `concat-context.sh`     | Look for `.yaml`/`.yml`; output YAML `description:`   |
| `context-scaffold.sh`   | Generate `.mwp-context.yaml` stub instead of `.md`    |
| `explore.sh`            | Find and report `.mwp-context.yaml` files              |
| `changes.sh`            | Include `.mwp-context.yaml` in change scanning         |
| `mwp-verify.sh`         | Parse guards from YAML directly (no `---` markers)    |
| `search.sh`             | (No code change — searches file contents, not names)   |
| `uninstall.sh`          | Find/delete `.mwp-context.yaml` instead of `.md`       |
| `mwp-up`                | Distribute `migrate-to-yaml.sh` alongside other scripts |
| `skills/mwp/SKILL.md`   | Update `.mwp-context.md` references                   |

**Key implementation notes for `concat-context.sh`:**
- Output wrapping changes from `<!-- context: path/.mwp-context.md -->` to
  `<!-- context: path/.mwp-context.yaml -->`.
- The YAML file's `description` key contains markdown — extract and render it
  as the body. Other keys (layer, scope, imports, guards) are metadata for the
  mapper; only `description` is displayed in the concatenated output.
- If no `description` key exists, emit only the comment header (the directory
  contributes no prose, only structural metadata).

**Key implementation notes for `context-scaffold.sh`:**
- Old stub was an HTML comment. New stub is minimal YAML:

```yaml
schema: 1
# TODO: Set layer (0–4) and scope (recursive or local).
#       Add a description, imports, and guards as needed.
#       See protocol.md for the full schema.
```

**Key implementation notes for `mwp-verify.sh`:**
- Currently parses YAML frontmatter from between `---` markers. With pure YAML,
  the entire file is YAML — just read it with a YAML parser or continue with
  the same grep-based approach (the `guards:` and `verified_paths:` keys are at
  the top level, same structure, just no `---` delimiters to skip).

---

## Verification (after implementation)

- [ ] `manual/migrate-to-yaml.sh` runs clean on a project with existing
      `.mwp-context.md` files — all are converted, originals deleted
- [ ] `manual/migrate-to-yaml.sh` is idempotent — running twice does nothing
      (second run: no `.md` files to migrate)
- [ ] `manual/concat-context.sh <target>` produces the same output (semantically)
      when run against `.mwp-context.yaml` files as it did against `.md` files
- [ ] `manual/context-scaffold.sh <dir>` creates `.mwp-context.yaml` with valid
      YAML, not `.mwp-context.md`
- [ ] `manual/bootstrap.sh` lists `.mwp-context.yaml` files in topology
- [ ] `manual/mwp-verify.sh` correctly parses `guards:` and `verified_paths:`
      from pure YAML files
- [ ] `manual/uninstall.sh` finds and removes `.mwp-context.yaml` files
- [ ] `manual/skills/mwp/SKILL.md` references `.mwp-context.yaml`
- [ ] All docs: no remaining `.mwp-context.md` reference (outside of migration
      notes and changelog)
- [ ] `proposal.md` code examples show `.mwp-context.yaml` with correct YAML
- [ ] All manual scripts pass `shellcheck` where applicable
