# Handoff: Make MWP skills discoverable by pi.dev (and other agent harnesses)

**Story ID:** — (not yet in roadmap)  
**Status:** ⬜ backlog  
**Depends on:** nothing

---

## Problem

The MWP manual ships three Agent Skills in `manual/skills/`:

```
manual/skills/
├── handoff/SKILL.md    # session handoff procedure
├── mapping/SKILL.md    # md-index navigation
└── mwp/SKILL.md        # workspace mapping protocol
```

`mwp-up` installs them into `.mwp/skills/`. They follow the [Agent Skills
standard](https://agentskills.io/specification) structurally (directory +
`SKILL.md` + valid frontmatter), but they are **not functional in practice**
for three reasons:

### 1. Wrong discovery path

pi.dev scans specific locations for skills: `.pi/skills/`, `.agents/skills/`,
`~/.pi/agent/skills/`, `~/.agents/skills/`. `.mwp/skills/` is not one of them.
The skills are installed but never loaded.

### 2. Path references are fragile

The skills use project-root-relative paths (`bash .mwp/changes.sh`). This works
when the agent's cwd is the project root, but the Agent Skills spec says
relative paths resolve from the skill directory. If the skill lives at
`.mwp/skills/mwp/SKILL.md`, the correct relative path to `.mwp/changes.sh` would
be `../../changes.sh`. In practice this usually works because agent harnesses
run with cwd = project root, but it is not guaranteed by the spec.

### 3. Generic names risk collision

`mwp`, `handoff`, `mapping` are short and un-namespaced. In shared setups with
skills from multiple sources, collisions are plausible. Better: `mwp-core`,
`mwp-handoff`, `mwp-mapping`.

---

## What needs to happen

### Fix A — Discovery path (required)

The skills must land in a directory pi.dev actually scans. Options:

| Approach | Pros | Cons |
|----------|------|------|
| Install to `.agents/skills/mwp/` directly | Zero config for users | Pollutes a generic directory with MWP-specific content |
| Symlink `.agents/skills/mwp` → `.mwp/skills` | Skills stay with MWP artifacts | Symlink maintenance; Windows unfriendly |
| Print pi.dev config snippet at install | Explicit, user-controlled | Extra manual step |
| Install to `.mwp/skills/` + add `"skills"` entry to `.pi/settings.json` | Automated | Touching another tool's config is invasive |

**Recommendation:** Install to `.agents/skills/mwp/` directly. It's the
simplest path, zero-config, and `.agents/skills/` is explicitly designed as a
shared skill location for project-level agent tools. The MWP skills belong
alongside other project agent skills.

Update `mwp-up`:
- Change `mkdir -p .mwp/skills/mwp` → `mkdir -p .agents/skills/mwp`
- Change all `fetch_file "$BASE_URL/skills/..." ".mwp/skills/..."` → `.agents/skills/mwp/...`
- Flatten the structure: `mwp/SKILL.md`, `handoff/SKILL.md`, `mapping/SKILL.md` all live directly in `.agents/skills/mwp/SUBDIR/SKILL.md`
- Update `.mwp/.gitignore` to reference the new path

### Fix B — Path references (recommended)

The skill scripts reference `.mwp/<script>` from project root. Two approaches:

1. **Switch to absolute-from-project-root notation.** Document that skills assume
   cwd = project root (which is true for pi.dev, Claude Code, and most harnesses).
   Add a note at the top of each skill: `<!-- Assumes cwd = project root -->`.
   This is the pragmatic choice — it works everywhere that matters.

2. **Switch to skill-directory-relative paths.** Change `bash .mwp/changes.sh` to
   `bash ../../changes.sh` (if skill is at `.agents/skills/mwp/mwp/SKILL.md` and
   scripts are in `.mwp/`). This is spec-compliant but fragile — if the install
   location changes, paths break. Also makes the skill harder to read (what is
   `../../`?).

**Recommendation:** Option 1. Add a one-line assumption note to each SKILL.md.
This is how most real-world skills work in practice — they assume cwd.

### Fix C — Namespace names (nice-to-have)

Rename:
- `mwp` → `mwp-core`
- `handoff` → `mwp-handoff`
- `mapping` → `mwp-mapping`

Update the `name:` field in each SKILL.md frontmatter. Directory names should
match (pi.dev doesn't enforce this but it's good practice).

---

## Files to change

| File | Change |
|------|--------|
| `manual/mwp-up` | Install skills to `.agents/skills/mwp/` instead of `.mwp/skills/`. Update `.gitignore` template. Update post-install message. |
| `manual/skills/mwp/SKILL.md` | Add cwd assumption note. Optionally rename to `mwp-core`. |
| `manual/skills/handoff/SKILL.md` | Add cwd assumption note. Optionally rename to `mwp-handoff`. |
| `manual/skills/mapping/SKILL.md` | Add cwd assumption note. Optionally rename to `mwp-mapping`. |
| `manual/uninstall.sh` | Also clean `.agents/skills/mwp/` if present. |
| `manual/protocol.md` | Update Agentic Skills & Hooks section to reference `.agents/skills/mwp/`. |
| `AGENTS.md` | Update skill paths in §6 (Commands) and §7 (Layout). |
| `manual/README.md` | Update any skill path references. |
| `manual/hooks/mwp-guard.sh` | Check if hook path references need updating. |

---

## Verification

- [ ] `mwp-up` on a clean project creates `.agents/skills/mwp/` with all three skills
- [ ] `pi.dev` launched in the project discovers and lists `mwp`, `handoff`, `mapping` skills
- [ ] `/skill:mwp` loads the workspace mapping protocol instructions
- [ ] `mwp-up` on a project with existing `.mwp/skills/` migrates cleanly (or warns)
- [ ] `uninstall.sh` removes `.agents/skills/mwp/`
- [ ] `.mwp/.gitignore` reflects the new paths
- [ ] All docs reference `.agents/skills/mwp/` not `.mwp/skills/`
