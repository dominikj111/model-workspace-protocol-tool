# Handoff: Make MWP skills discoverable by all agent harnesses

**Story ID:** 00a  
**Status:** ⬜ backlog  
**Depends on:** nothing  
**Goal:** MWP skills must work in pi.dev, Claude Code, OpenCode, OpenClaude,
and any other harness that follows the Agent Skills standard.

> **Note (later decision):** the `handoff` skill was removed in a later chore
> (its mwp-specific parts — verify, record, orient-next-session — were folded
> into the `mwp` skill). Only `mwp` and `mapping` ship as installable skills
> now, plus `maintaining-mwp-contexts`. The rename rows for `handoff` in the
> Files-to-change table below are stale.

---

## Context — the cross-tool landscape

The [Agent Skills standard](https://agentskills.io/specification) defines a
common format (directory + `SKILL.md` + frontmatter) but discovery paths are
tool-specific. The standard recommends `.agents/skills/` as the shared
project-level location. Adoption varies:

| Tool | Native skill paths | Notes |
|------|-------------------|-------|
| **pi.dev** | `.pi/skills/`, `.agents/skills/`, `~/.pi/agent/skills/`, `~/.agents/skills/` | `.agents/skills/` works natively ✅ |
| **Claude Code** | `.claude/skills/` | Also accepts config: `"skills"` in settings |
| **OpenCode** | Unknown (likely `.agents/skills/` or config-based) | TBD during implementation |
| **OpenClaude** | Unknown | TBD during implementation |
| **Other stdlib harnesses** | `.agents/skills/` (per standard) | Goal: zero-config for any compliant tool |

**Strategy:** Install to `.agents/skills/mwp/` as the single source of truth. For
tools that don't scan it natively, `mwp-up` prints a one-time config snippet. No
symlinks, no duplication — one canonical location, documented per-tool bridges.

---

## Problem

The MWP manual ships three Agent Skills in `manual/skills/`:

```
manual/skills/
├── handoff/SKILL.md    # session handoff procedure
├── mapping/SKILL.md    # md-index navigation
└── mwp/SKILL.md        # workspace mapping protocol
```

`mwp-up` installs them into `.mwp/skills/`. They follow the Agent Skills
standard structurally (directory + `SKILL.md` + valid frontmatter), but they
are **not functional in any harness** for three reasons:

### 1. Wrong discovery path for every tool

`.mwp/skills/` is not in any tool's scan list. No harness discovers them. The
single canonical install target should be `.agents/skills/mwp/` — the
cross-tool location recommended by the Agent Skills standard.

### 2. Path references are fragile

The skills use project-root-relative paths (`bash .mwp/changes.sh`). This works
when the agent's cwd is the project root, but the spec says relative paths
resolve from the skill directory. In practice this usually works because most
harnesses set cwd = project root, but it is not guaranteed.

### 3. Generic names risk collision

`mwp`, `handoff`, `mapping` are short and un-namespaced. In shared setups with
skills from multiple sources, collisions are plausible. Better: `mwp-core`,
`mwp-handoff`, `mwp-mapping`.

---

## Fixes

### Fix A — Single install target, per-tool bridges (required)

Install skills to `.agents/skills/mwp/`. This is the Agent Skills standard's
recommended shared location and works natively in pi.dev.

For tools that don't scan `.agents/skills/` natively, `mwp-up` prints a
post-install snippet:

```
  Skills installed to .agents/skills/mwp/

  Skill discovery:
    pi.dev             ✅ works natively
    Claude Code         → add this to .claude/settings.json:
                          { "skills": [".agents/skills"] }
    OpenCode            → (check docs; likely same as above)
    OpenClaude          → (check docs; likely same as above)
```

No symlinks, no duplication. One canonical location; documented bridges.

Changes to `mwp-up`:
- Change `mkdir -p .mwp/skills/mwp` → `mkdir -p .agents/skills/mwp`
- Change all `fetch_file "$BASE_URL/skills/..." ".mwp/skills/..."` → `.agents/skills/mwp/...`
- Update `.mwp/.gitignore` to reference new path
- Add per-tool config snippet to post-install message
- Handle migration: if `.mwp/skills/` exists from a prior install, move content
to `.agents/skills/mwp/` and warn about the old directory

### Fix B — Document cwd assumption (recommended)

Add a note to each SKILL.md:

```markdown
<!-- Assumes cwd = project root (standard for pi.dev, Claude Code, and most harnesses). -->
```

This is the pragmatic choice. Switching to skill-directory-relative paths
(`../../changes.sh`) is spec-compliant but fragile — if the install location
changes, paths break. Most real-world skills in the ecosystem assume cwd.

### Fix C — Namespace names (nice-to-have)

Rename in each SKILL.md frontmatter:
- `mwp` → `mwp-core`
- `handoff` → `mwp-handoff`
- `mapping` → `mwp-mapping`

Directory names should match (pi.dev doesn't enforce this, but the standard
does, and matching avoids confusion).

---

## Files to change

| File | Change |
|------|--------|
| `manual/mwp-up` | Install to `.agents/skills/mwp/`. Update `.gitignore` template. Add per-tool config snippet to post-install message. Handle migration from `.mwp/skills/`. |
| `manual/skills/mwp/SKILL.md` | Add cwd assumption note. Rename `name:` to `mwp-core`. |
| `manual/skills/handoff/SKILL.md` | Add cwd assumption note. Rename `name:` to `mwp-handoff`. |
| `manual/skills/mapping/SKILL.md` | Add cwd assumption note. Rename `name:` to `mwp-mapping`. |
| `manual/uninstall.sh` | Also clean `.agents/skills/mwp/` and stale `.mwp/skills/` if present. |
| `manual/protocol.md` | Update Agentic Skills & Hooks section to reference `.agents/skills/mwp/`. |
| `AGENTS.md` | Update skill paths in §6 (Commands) and §7 (Layout). |
| `manual/README.md` | Update any skill path references. |

---

## Verification

- [ ] `mwp-up` on a clean project creates `.agents/skills/mwp/` with all three skills
- [ ] `pi.dev` launched in the project discovers and lists the skills natively
- [ ] `/skill:mwp-core` loads the workspace mapping protocol instructions
- [ ] Claude Code with `"skills": [".agents/skills"]` in settings discovers them
- [ ] OpenCode / OpenClaude: at minimum, documented how to bridge (test if possible)
- [ ] `mwp-up` on a project with existing `.mwp/skills/` migrates cleanly (moves + warns)
- [ ] `uninstall.sh` removes `.agents/skills/mwp/` and stale `.mwp/skills/`
- [ ] `.mwp/.gitignore` reflects the new paths
- [ ] All docs reference `.agents/skills/mwp/`, not `.mwp/skills/`
- [ ] Post-install message shows correct per-tool config for the current tool landscape
