# AGENTS.md — MWP (Model Workspace Protocol) Tool

## Purpose

Spec-stage project: a deterministic **workspace mapper** — a future Rust CLI + MCP server (proposal §10–§12) that assembles layered LLM context from a project's folder tree. Delivered today as a lightweight shell implementation in `manual/`, whose job is to answer "is this worth building?". Success: the manual experiment proves the cascade concept before the Rust toolchain is built.

## Navigation

| Need | Read |
|------|------|
| Design, architecture, decisions | `docs/proposal.md` (long — read the §N cited on the active story card; index: `docs/index.md`) |
| Normative formats, algorithms | `docs/format-spec.md` |
| User-facing manual protocol | `manual/protocol.md` |
| Manual scripts — install, use, upgrade | `manual/README.md` |
| What's done / what's next | `roadmap/ROADMAP.md` + newest `roadmap/handoffs/` |
| MWP session skills | `manual/skills/` (mwp, handoff, mapping, maintaining-mwp-contexts) |

## Rules

- `docs/proposal.md` is the design contract — behavior changes must trace to it or to a deliberate, user-approved amendment.
- Context files are **pure YAML** (`.mwp-context.yaml`, alias `.yml`). Legacy `.mwp-context.md` is still read but flagged for migration — `manual/migrate-to-yaml.sh` converts it.
- A context's `description` is human-authored markdown prose, carried verbatim; it may become the boundary `AGENTS.md` when a module is extracted to a standalone repo. The tool never invents or summarizes.
- Manual scripts are user-facing (`curl | sh`): readable, safe, self-contained — bash + curl only, no hidden dependencies. Shell is the medium, not Rust.
- Markdown is the product — proofread rendered output.
- Non-goals: the tool does not generate context, does not enforce pipeline discipline, and this repo does not contain the CLI implementation yet.

## Workflow

Read the current story card + latest handoff → the proposal §N cited on the card → trace before abstracting → smallest coherent change → validate end-to-end.

## Validation

- Affected manual workflow run end-to-end (fixture project)
- `shellcheck` clean on changed scripts where applicable
- Markdown output proofread
- Aligned with the proposal (cite §N)

## Context

Instantiated from the ICM/MWP and project-structure workspace guidelines — reference them by topic name, do not duplicate their conventions here. Status lives in `roadmap/`; design in `docs/`. Role, tone, and methodology come from the workspace profile.
