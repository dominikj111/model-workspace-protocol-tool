# Releasing the manual implementation

The manual implementation ships from `main` — **no tags, no release assets**.
`mwp-up` and `upgrade.sh` fetch from
`raw.githubusercontent.com/dominikj111/model-workspace-protocol-tool/main/manual`,
so **the push to `main` is the release**. Tagging starts only with the Rust CLI
(proposal §10), which will ship as binaries / `cargo install`.

## How users update

- **`bash .mwp/upgrade.sh`** — compares the installed `.mwp/protocol.md` version
  with the remote one; if older, re-runs `mwp-up` (full reinstall from `main`).
- **Re-running the `curl | sh` install** — refreshes everything regardless of
  version.

`version:` in `manual/protocol.md` frontmatter is the single source of truth for
upgrade detection. Keep it in sync with every release — a release without a bump
is invisible to `upgrade.sh`.

## Release procedure

1. **Verify the manual end-to-end** (checklist below).
2. **Bump `version:` in `manual/protocol.md`** (semver; pre-1.0, `0.x` minors are
   fine for user-visible changes). Add a changelog entry below.
3. Commit — `chore: release manual <ver> — <summary>` — and push to `main`.

That is the release. Nothing else to publish.

## Verification checklist (run before bumping)

- [ ] `bash -n` on all scripts (`manual/*.sh`, `manual/mwp-up`)
- [ ] `shellcheck -S warning` clean on changed scripts
- [ ] Fresh install on a clean project (`curl | sh`) — bootstrap prompt works
- [ ] Upgrade path: install the previous version into a fixture, run the current
      `mwp-up` over it — new scripts present, removed skills pruned, old
      `.mwp-context.md` files still read (legacy fallback)
- [ ] `upgrade.sh` version logic: `version_lt <installed> <remote>` decides
      correctly (older → reinstall, equal → up to date)
- [ ] Cascade: `concat-context.sh` on a mixed tree (yaml + yml + legacy md)
- [ ] `migrate-to-yaml.sh` converts in place and is idempotent
- [ ] `md-index.sh <file> --format text` outputs headers only
- [ ] Markdown output proofread (protocol.md, README.md)

## Changelog

### 0.4.0 — 2026-08-16

- **Context format migrated to pure YAML** — `.mwp-context.yaml` (alias `.yml`),
  body in a `description` key, required `schema: 1`. Legacy `.mwp-context.md` is
  still read (cascade falls back to it); `migrate-to-yaml.sh` converts in place.
- `concat-context.sh` renders only the `description` key from YAML files.
- `mwp-verify.sh` parses `guards:` / `verified_paths:` from pure YAML and legacy
  frontmatter.
- `md-index.py` outputs headers only (title/level/parent/start/end, no prose
  hints); text format shows `L<start>–<end>` ranges.
- Skills: `handoff` removed (its mwp-specific parts folded into `mwp`); `mapping`
  rewritten cascade-aware (never index files the cascade already delivers).
- Docs: `proposal.md` moved to `docs/` with `docs/index.md` entry point;
  `docs/format-spec.md` removed (merged into the proposal, §5.2 key table).

### 0.3.0 and earlier

Predate this changelog; version history lives in git.
