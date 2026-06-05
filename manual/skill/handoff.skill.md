---
name: handoff
description: Use to hand off the current task and state to another agent or session.
---

# Handoff Procedure

When ending a session or transferring work:

1.  **Summarize Progress**: Update `.mwp/discoveries.md` with:
    *   What was accomplished.
    *   What is currently "in progress".
    *   What the next immediate steps are.
2.  **Verify State**: Run `bash .mwp/mwp-verify.sh` to ensure all changes are valid.
3.  **Handoff Message**: Provide the following to the next agent:
    *   "Orient using MWP: Read `.mwp/topology.md` and `.mwp/discoveries.md`."
    *   "Current Focus: [Brief description]"
    *   "Context: Run `bash .mwp/concat-context.sh <active-dir>`"
4.  **Traceability**: Provide a single-line commit message draft covering *only* the `.mwp/` directory updates (ignoring project-specific code changes).
