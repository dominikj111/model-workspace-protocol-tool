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

1.  **Load Cascade**: Run `bash .mwp/concat-context.sh <target-path>` to inject the `.mwp-context.md` hierarchy.
    *   *Note: Run once per session per target. Do not waste tokens re-running for the same scope.*
2.  **Record Findings**: If you learn something new from the cascade or code, update `.mwp/discoveries.md` immediately.

## 🛡️ Verification & Safety

Before any **side-effect actions** (writes, deletes, commits, deploys):

1.  **Verify**: Run `bash .mwp/mwp-verify.sh [target-directory]`.
    *   **Exit 0**: Proceed normally.
    *   **Exit 1**: Context is **READ-ONLY**. Report failures to the user and do not apply changes.

## 📝 Documenting the Terrain

*   **Topology**: Regenerate via `bash .mwp/bootstrap.sh` if directory structure changes significantly.
*   **Context Files**: Create `.mwp-context.md` in key directories to describe ownership and constraints. Use `bash .mwp/context-scaffold.sh <dir>`.
*   **Discoveries**: Always suffix inferences with `?` (e.g., `stack?: Go`). Be factual and traceable.
