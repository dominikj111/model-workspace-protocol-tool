---
name: mwp
description: Use for workspace mapping, discovery, and context loading. Follow the MWP (Minimum Viable Protocol).
---

# MWP Workspace Protocol

A system for persistent, cumulative project mapping. Instead of re-deriving structure every session, use the topology and discoveries stored in `.mwp/`.

## 🚀 Session Start Orientation

At the beginning of every session, you MUST:

1.  **Orient**: Run `bash .mwp/changes.sh` to see recent activity and check if `topology.md` is stale.
2.  **Read Map**: Read `.mwp/topology.md` (structural index) and `.mwp/discoveries.md` (accumulated knowledge).

## 🔍 Context Enrichment (Target Identification)

Once a target file or directory is identified, follow this sequence **BEFORE** doing any work:

1.  **Load Cascade**: Run `bash .mwp/concat-context.sh <target-path>` to inject the `.mwp-context.yaml` hierarchy.
    *   *Note: Run once per session per target. Do not waste tokens re-running for the same scope.*
2.  **Record Findings**: If you learn something new from the cascade or code, update `.mwp/discoveries.md` immediately.

## 🛡️ Verification & Safety

Before any **side-effect actions** (writes, deletes, commits, deploys):

1.  **Verify**: Run `bash .mwp/mwp-verify.sh [target-directory]`.
    *   **Exit 0**: Proceed normally.
    *   **Exit 1**: Context is **READ-ONLY**. Report failures to the user and do not apply changes.

## 🔄 Handoff (end of session)

When ending a session or transferring work:

1.  **Verify**: Run `bash .mwp/mwp-verify.sh` and resolve failures before leaving.
2.  **Record**: Write findings, in-progress state, and next steps into `.mwp/discoveries.md`.
3.  **Orient the next session**: Leave a one-line pointer —
    "Orient using MWP: read `.mwp/topology.md` and `.mwp/discoveries.md`; run `bash .mwp/concat-context.sh <active-dir>`."

## 📝 Documenting the Terrain

*   **Topology**: Regenerate via `bash .mwp/bootstrap.sh` if directory structure changes significantly.
*   **Context Files**: Proactively maintain `.mwp-context.yaml` files in key directories.
    *   **Scope**: These are strictly descriptive "mini-AGENTS.md" terrain maps, not session memory or work logs.
    *   **Propose Update**: If you learn stable architectural rules or "surprises", ask the user if you should record them to save future tokens.
    *   **Create**: Use `bash .mwp/context-scaffold.sh <dir>` for new scopes.
*   **Discoveries**: Always suffix inferences with `?` (e.g., `stack?: Go`). Be factual and traceable.
