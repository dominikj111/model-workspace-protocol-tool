# MWP (Model Workspace Protocol) Tool

Deterministic workspace mapper that assembles layered LLM context from your project's folder tree — CLI and MCP server specification.

## What it is

MWP is a specification for a CLI tool (and MCP server) that produces a **workspace map**: a structured, layered, token-budgeted artifact that orients an LLM for work in a specific part of a project. Given a target file path, the mapper walks the directory tree, collects `.mwp-context.yaml` files along the cascade, resolves imports from community modules, optionally runs verification scripts, and renders a map the LLM can use immediately.

The map is not content — it is orientation. Source code remains primary; the `.mwp-context.yaml` files are the map layer that sits alongside it.

This work builds on Jake Van Clief and David McDermott's *Interpretable Context Methodology* ([arXiv:2603.16021v1](https://arxiv.org/html/2603.16021v1), 2026) and adds two things the paper does not specify: a deterministic assembly tool and a community module ecosystem for sharing domain expertise.

## Use it today — manual implementation

A shell-script implementation is available in [`manual/`](manual/) and works right now,
without waiting for the CLI to be built. It provides the same cascade workflow — topology
map, `.mwp-context.yaml` files, session-start orientation — using only `bash` and `curl`.

```bash
curl --proto '=https' --tlsv1.2 -sSf \
  https://raw.githubusercontent.com/dominikj111/model-workspace-protocol-tool/main/manual/mwp-up | sh
```

→ [manual/README.md](manual/README.md) for full details.

---

## Status

**Specification/proposal stage.** No CLI implementation exists yet. The document in this
repository is a design specification intended to guide the eventual Rust implementation.

## Read the spec

→ [docs/proposal.md](docs/proposal.md) — or start with the [design index](docs/index.md)

## Key ideas

- **Cascade traversal** — `.mwp-context.yaml` at each directory level is optional; the mapper collects what exists and skips what doesn't (legacy `.mwp-context.md` still read during migration)
- **Community modules** — domain expertise (Rust idioms, Django conventions, stack-specific rules) shared as pinned Git imports
- **Verified references** — guards: scripts that confirm the codebase satisfies a constraint before the map includes it
- **Two-phase lensing** — sessions start with a project orientation map, then narrow to a focused file-level map
- **Spread memory** — orientation knowledge distributed across the tree at the level it describes: scoped retrieval, error isolation, and cross-module convention propagation — RAG's motivation without RAG's mechanism (resolution stays path-based and explainable)
- **MCP server** — same binary, exposes the mapper to any MCP-aware LLM client with incremental delta delivery per connection

## When to use it — and when to skip it

Honest guidance, from real use. MWP is a **map layer, not content**: it makes orientation
cheap and repeatable, but the map is only as good as its upkeep. A stale map misleads worse
than no map — expect to maintain the `.mwp-context.yaml` cascade as the project changes.

**MWP earns its place when:**

- The project is **large or sprawling** — many directories, modules, or sub-projects where
  finding the right context is the expensive part of a session.
- **Multiple agents or contributors** work in the repo, or you onboard new ones frequently —
  orientation becomes repeatable instead of tribal knowledge.
- You want **deterministic, budgeted context**: the same map every time, token-aware, so a
  session starts oriented without dumping the whole tree.
- You work across **many projects** and want one consistent orientation workflow — the same
  cascade everywhere, plus reusable **community modules** (pinned imports of domain
  expertise) instead of rewriting conventions per repo.
- **Session continuity** matters: the cascade + handoffs keep a coherent picture across
  sessions, and verified references (guard scripts) confirm constraints before the map
  claims them.

**Skip it when:**

- The project is **small and already well-oriented** — a good `AGENTS.md` + roadmap + docs
  index often beats a context map. MWP pays off when orientation is genuinely expensive;
  for a single-crate, one-contributor repo it is usually overhead.
- You're the **only contributor** and carry the structure in your head — the upkeep can
  outlive the benefit.
- You **won't maintain the cascade** — again: a stale map misleads worse than none.
- The repo is **public and deliberately minimal** — every tool layer is surface; map the
  project when it grows, not from day one, unless you want to map from the start.

If in doubt: start without it, and adopt MWP when not being oriented starts costing more
than maintaining the map.

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
