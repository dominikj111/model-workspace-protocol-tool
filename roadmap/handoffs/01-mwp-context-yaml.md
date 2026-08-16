# Handoff: `.mwp-context.md` → `.mwp-context.yaml`

**Story ID:** 00 — Context format migration
**Status:** ⬜ backlog → ✅ done
**Proposal refs:** §5.2 (context files), §5.3 (modules), §5.4 (cache), §8 (IR), §9 (CLI)

---

## Delivered

**Format.** The context format is now pure YAML: `.mwp-context.yaml` (canonical),
`.mwp-context.yml` (alias), body moved into a `description` literal-block key,
required `schema: 1`. Proposal §5.2 rewritten with a pure-YAML example; the
granularity-split and interpolation examples updated; "frontmatter" wording
cleaned up everywhere it described the old format. `docs/format-spec.md` updated
to current state.

**Migration script.** New `manual/migrate-to-yaml.sh`: finds `.mwp-context.md`
files (respecting `.mwpignore`), extracts frontmatter/body (first `---` pair
only), moves the body into `description` (omitted when empty or stub-only),
adds `schema: 1`, rewrites legacy `verified_paths: - .mwp-context.md` entries,
converts tabs, validates via python3-yaml when available, deletes originals only
after a valid `.yaml` was written. Idempotent; reports migrated/skipped/errors.

**Reader scripts updated to yaml → yml → md lookup:**
- `concat-context.sh` — renders only the `description` key from YAML files
  (markdown prose); legacy `.md` emitted whole; stale-`.md` and yaml+yml
  warnings
- `context-scaffold.sh` — creates a minimal `schema: 1` YAML stub; refuses to
  overwrite yaml/yml/md
- `bootstrap.sh`, `explore.sh` — find `.mwp-context.*` (all three); ancestor
  cascade checks yaml → yml → md
- `changes.sh` — freshness scan includes all three
- `mwp-verify.sh` — parses `guards:` / `verified_paths:` from pure YAML and
  legacy frontmatter (shared `yaml_lines` helper); context lookup yaml → yml → md
- `uninstall.sh` — counts and removes all three
- `mwp-up` — distributes `migrate-to-yaml.sh`; `.mwp/.gitignore` template updated

**Docs:** `manual/protocol.md`, `manual/README.md`, `README.md`,
`manual/skills/mwp/SKILL.md`, `manual/skills/maintaining-mwp-contexts/SKILL.md`
updated. `AGENTS.md` rewritten into the structure-guideline shape (49 lines,
Purpose/Navigation/Rules/Workflow/Validation/Context) and references the new
format. `docs/index.md` added; `proposal.md` relocated to `docs/proposal.md`
(separate docs commit).

**Roadmap:** S-00 flipped ✅; "Current state" section added to `ROADMAP.md`.

## Decisions & deviations

- **`md` stays readable (user override).** Handoff 01 originally specified a
  breaking change (`.mwp-context.md` unsupported after migration). Per the
  user's instruction, the readers still accept legacy `.mwp-context.md`, and
  the cascade falls back to it — a partially migrated tree keeps working.
  `migrate-to-yaml.sh` converts and deletes originals; `mwp lint` is specified
  to warn on stale `.md` beside `.yaml`.
- **AGENTS.md-extraction constraint (user instruction).** The `description` key
  is the content that may become the boundary `AGENTS.md` when a module is
  extracted to a standalone repo (ties into story 00c's materialised-AGENTS.md
  design). Documented in proposal §5.2, format-spec, and protocol.md; the
  migration preserves the body verbatim so the round-trip is lossless.
- **`verified_paths: - .mwp-context.md`** entries are rewritten to
  `.mwp-context.yaml` during migration (the old proposal example listed the
  context file itself).
- **Pre-existing bug fixed:** `mwp-verify.sh` used `${#VP[@]:-0}`, a bad
  substitution under bash ≥ 5 — the script aborted whenever a context file
  existed. Replaced with `${#VP[@]}` (one line, required to verify this story).
- **Not in scope:** `.mwp-module.md` keeps its markdown+frontmatter format
  (story 42); bootstrap.sh's pre-existing `mwp_find` eval warnings were left
  untouched (not part of this story, working code).
- **Structure work bundled:** `docs/` relocation (proposal + index) and the
  AGENTS.md rewrite rode along in separate commits — flagged to the user
  explicitly as guideline-driven, not story-00 scope.

## Verification

- Fixture project (`/tmp/mwp-fixture`): migration converted 3/3 valid files
  (full-featured, frontmatter-only, stub-only), skipped conflict (yaml sibling)
  and invalid (no frontmatter) files, rewrote verified_paths, preserved
  indented markdown and a stray `---` inside the body, idempotent second run.
- `concat-context.sh`: yaml + yml + legacy md cascade output correct; blank
  lines and markdown indentation round-trip verbatim; description-only rendering
  confirmed (no-description files emit only the comment header).
- `context-scaffold.sh`: creates valid YAML stub; refuses existing yaml/yml/md.
- `bootstrap.sh` / `explore.sh`: list all three formats; ancestor cascade
  correct.
- `mwp-verify.sh`: yaml guards pass/fail/read-only paths correct; legacy md
  frontmatter guards still parse.
- `shellcheck 0.10.0` clean on all changed scripts (bootstrap.sh's untouched
  `mwp_find` helper excluded — pre-existing).
- Note: no YAML parser available on this host — `validate_yaml` is best-effort
  (python3+yaml when present); validity was verified by construction against
  the canonical literal-block form and by round-trip behavior.

## Known issues

- `migrate-to-yaml.sh` skips a `.md` when a `.yaml`/`.yml` sibling exists
  (conflict left for the author) — no auto-merge.
- `concat-context.sh` description extraction assumes the canonical 2-space
  block indentation; deeper author-chosen indentation leaves extra leading
  spaces in the rendered body.
- This repo itself has no `.mwp-context.*` files, so the migration ran against
  a fixture; projects with real contexts should run
  `bash .mwp/migrate-to-yaml.sh` and review the diff.
- python3-yaml validation is optional; a project with python3 but no yaml
  module gets construction-trust instead.

## Hand-off to next story

Next: **00a (skills discovery, handoff 02)**. Note: `docs/format-spec.md` was
removed in the 00b resolution (merged into the proposal — its key table now
lives in §5.2; `docs/index.md` is the entry point). The handoff skill was also
removed in a later chore (its mwp-specific parts folded into the mwp skill) —
00a's rename plan for `mwp-handoff` is stale; only `mwp` + `mapping` remain.
