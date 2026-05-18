# MWP Workspace Protocol — Pre-tool Manual Implementation

A drop-in workspace mapping protocol for LLM-assisted development.
Works today, without waiting for the mwp-tool CLI to be built.

The idea: instead of re-deriving project structure and conventions from scratch every session,
give your AI assistant a persistent, cumulative map of the project — topology, conventions,
boundaries — assembled once and enriched over time.

---

## Quickstart

Run from your project root:

```bash
curl --proto '=https' --tlsv1.2 -sSf \
  https://raw.githubusercontent.com/dominikj111/model-workspace-protocol-tool/main/manual/mwp-up | sh
```

This creates `.mwp/` in your project with:

| File                    | Purpose                                                                         |
| ----------------------- | ------------------------------------------------------------------------------- |
| `bootstrap.sh`          | Scans the project and generates `topology.md`                                   |
| `explore.sh`            | Ad-hoc map of any directory — the AI assistant's "digital eyes"                 |
| `concat-context.sh`     | Concatenates the `.mwp-context.md` cascade to a target — run once per session   |
| `changes.sh`            | Session-start orientation: recent commits, uncommitted state, topology status   |
| `search.sh`             | `.mwpignore`-aware code search — `bash .mwp/search.sh <pattern> [path]`         |
| `context-scaffold.sh`   | Creates a `.mwp-context.md` stub in a directory for the AI to fill in           |
| `protocol.md`           | Instructions for the AI assistant — load this in CLAUDE.md                      |
| `topology.md`           | Generated structural index (sub-projects, entry points, schemas, config)        |
| `discoveries.md`        | Cumulative findings written by the AI across sessions (starts empty)            |

At the end of setup, the installer prints a ready-to-paste `CLAUDE.md` block.

---

## Re-running bootstrap

Regenerate `topology.md` any time the project structure changes:

```bash
bash .mwp/bootstrap.sh
```

Relevant triggers: new sub-projects added, manifests changed, major directories restructured.

---

## Ad-hoc exploration

Get an instant map of any directory without storing anything:

```bash
bash .mwp/explore.sh              # current directory
bash .mwp/explore.sh ./backend    # specific path
```

Outputs structure, sub-project markers, entry points, config files, and the ancestor
`.mwp-context.md` cascade for that location. Useful as the AI assistant's "digital eyes"
when lensing into a new area mid-session.

---

## Loading the .mwp-context.md cascade

Once the target is known, concatenate all `.mwp-context.md` files from root to target:

```bash
bash .mwp/concat-context.sh ./backend/src/api/routes.ts
bash .mwp/concat-context.sh ./frontend
```

Run this **once per session** — the output goes directly into the LLM's context and
running it again wastes tokens. The protocol instructs the AI assistant to do this
automatically when a target is identified.

---

## Customising exclusions

Add a `.mwpignore` file at the project root (created automatically on first bootstrap):

```text
# One pattern per line — grep -vE semantics, matched against full paths
generated/
vendor/
fixtures/
*.snap
```

`node_modules/`, `.git/`, and `target/` are always excluded regardless.

---

## How it works with your AI assistant

`protocol.md` tells the assistant to:

1. Run `changes.sh` and read `topology.md` and `discoveries.md` at session start.
2. When a target is known, run `concat-context.sh` once to load the `.mwp-context.md` cascade.
3. Write any new findings into `discoveries.md` for future sessions.

`discoveries.md` accumulates across sessions — each session fills in gaps the previous one left.
The map grows as the project is explored, without re-scanning from scratch each time.

---

## Version control

`mwp-up` writes a `.mwp/.gitignore` that tracks only the two data files and ignores
all scripts. No manual configuration needed — just commit what git sees:

- **`.mwp/topology.md`** — regenerable, but committing means the team shares the same map
  without each person running bootstrap after a clone.
- **`.mwp/discoveries.md`** — permanent accumulated findings; must be committed or knowledge
  is lost between machines and contributors.
- **`.mwp-context.md` files** — scattered across the project tree alongside source code;
  commit them like any other source file.

Scripts are gitignored and re-fetched on demand. After a fresh clone, run:

```bash
curl --proto '=https' --tlsv1.2 -sSf \
  https://raw.githubusercontent.com/dominikj111/model-workspace-protocol-tool/main/manual/mwp-up | sh
```

`mwp-up` skips any files that already exist, so re-running it is always safe.

---

## Removing MWP from a project

```bash
bash .mwp/uninstall.sh
```

Removes `.mwp/`, all `.mwp-context.md` files in the project tree, and `.mwpignore` — with
a confirmation prompt and a count of what will be deleted. Then drop the `@.mwp/protocol.md`
line (and the session-start block) from your `CLAUDE.md`.

---

## Files in this folder

| File                    | Role                                                                            |
| ----------------------- | ------------------------------------------------------------------------------- |
| `mwp-up`                | Installer — downloaded and piped to sh via curl                                 |
| `bootstrap.sh`          | Bootstrap script — downloaded to `.mwp/bootstrap.sh`                            |
| `explore.sh`            | Ad-hoc local map — downloaded to `.mwp/explore.sh`                              |
| `concat-context.sh`     | Cascade concatenator — downloaded to `.mwp/concat-context.sh`                   |
| `changes.sh`            | Session-start orientation — downloaded to `.mwp/changes.sh`                     |
| `search.sh`             | `.mwpignore`-aware search — downloaded to `.mwp/search.sh`                      |
| `context-scaffold.sh`   | `.mwp-context.md` stub writer — downloaded to `.mwp/context-scaffold.sh`        |
| `uninstall.sh`          | Removal script — downloaded to `.mwp/uninstall.sh`                              |
| `protocol.md`           | Protocol instructions — downloaded to `.mwp/protocol.md`                        |

`mwp-up` downloads all scripts and `protocol.md` directly from this folder —
single source of truth, no embedded copies, no drift.
