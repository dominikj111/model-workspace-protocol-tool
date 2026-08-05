---
name: mapping
description: Use to index large Markdown files when targeted reading saves tokens over reading the full file.
---

# Markdown Mapping Skill

Use `md-index.sh` to map the structure of large Markdown files **before deciding
how to read them.** It is not always the right move — there is a threshold where
the TOC overhead exceeds just reading the file.

## When to use

| File size | Guidance |
|-----------|----------|
| **< 300 lines** | Skip md-index. Read the whole file. |
| **300–800 lines** | Use md-index only if you have a specific topic in mind. |
| **> 800 lines** | Always use md-index first. |

## 🚀 Procedure

1.  **Index the file** (prefer `--format text` for LLM consumption — ~60% fewer tokens):
    ```bash
    bash .mwp/md-index.sh <file> --format text
    ```
2.  **Identify the relevant sections** from the TOC. Check the `end` line —
    that is where the next section begins. Read from `start` to `end`.
3.  **If unsure which section you need**, skip the TOC and read the file
directly. The cost of guessing wrong and reading a second section can exceed
reading the full file from the start.

## 🛠️ Reference

```bash
bash .mwp/md-index.sh <file>                 # YAML (machine-readable)
bash .mwp/md-index.sh <file> --format text   # Compact (prefer for LLM)
bash .mwp/md-index.sh <file> --format json   # JSON
```
