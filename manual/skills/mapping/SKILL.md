---
name: mapping
description: Use to navigate large Markdown files when targeted reading saves tokens over reading the full file. MWP's alternative to a plain heading index — cascade-aware.
---

# Markdown Mapping — navigate large files with md-index

In an MWP session the cascade already delivers the context files along the path —
**never index those**. Indexing is for **terrain files**: large design docs
(`proposal.md`), protocol files, or source files too big to read whole.

Use `bash .mwp/md-index.sh <file>` to get a section index before deciding how to
read a large file. It is not always the right move — there is a threshold where
the index overhead exceeds just reading the file.

## When to use

**First, check the file size** with `wc -l <file>` (cheap — one command, one number).
Then apply:

| File size | Guidance |
|-----------|----------|
| **< 300 lines** | Skip md-index. Read the whole file. |
| **300–800 lines** | Use md-index only if you have a specific topic in mind. |
| **> 800 lines** | Always use md-index first. |

## Procedure

1.  **Index the file** (prefer `--format text` for LLM consumption — fewer tokens):
    ```bash
    bash .mwp/md-index.sh <file> --format text
    ```
2.  **Pick the relevant sections** from the headings. Each entry carries its line
    range (`L<start>–<end>`) — read only that span, then jump to the next section
    at its start line. `parent` in the YAML/JSON output shows the nesting.
3.  **If unsure which section you need**, skip the index and read the file
    directly. The cost of guessing wrong and reading a second section can exceed
    reading the full file from the start.

## Reference

```bash
bash .mwp/md-index.sh <file>                 # YAML (machine-readable)
bash .mwp/md-index.sh <file> --format text   # Compact (prefer for LLM)
bash .mwp/md-index.sh <file> --format json   # JSON
```
