# MWP (Model Workspace Protocol) Tool

Deterministic workspace mapper that assembles layered LLM context from your project's folder tree — CLI and MCP server specification.

## What it is

MWP is a specification for a CLI tool (and MCP server) that produces a **workspace map**: a structured, layered, token-budgeted artifact that orients an LLM for work in a specific part of a project. Given a target file path, the mapper walks the directory tree, collects `CONTEXT.md` files along the cascade, resolves imports from community modules, optionally runs verification scripts, and renders a map the LLM can use immediately.

The map is not content — it is orientation. Source code remains primary; the `CONTEXT.md` files are the map layer that sits alongside it.

This work builds on Jake Van Clief and David McDermott's *Interpretable Context Methodology* ([arXiv:2603.16021v1](https://arxiv.org/html/2603.16021v1), 2026) and adds two things the paper does not specify: a deterministic assembly tool and a community module ecosystem for sharing domain expertise.

## Status

**Specification/proposal stage.** No implementation exists yet. The document in this repository is a design specification intended to guide the eventual Rust implementation.

## Read the spec

→ [proposal.md](proposal.md)

## Key ideas

- **Cascade traversal** — `CONTEXT.md` at each directory level is optional; the mapper collects what exists and skips what doesn't
- **Community modules** — domain expertise (Rust idioms, Django conventions, stack-specific rules) shared as pinned Git imports
- **Verified references** — guards: scripts that confirm the codebase satisfies a constraint before the map includes it
- **Two-phase lensing** — sessions start with a project orientation map, then narrow to a focused file-level map
- **MCP server** — same binary, exposes the mapper to any MCP-aware LLM client with incremental delta delivery per connection

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
