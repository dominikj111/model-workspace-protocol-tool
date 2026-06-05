---
name: mapping
description: Use to index large Markdown files before reading them to identify relevant sections.
---

# Markdown Mapping Skill

When dealing with large Markdown files, use `md-index.sh` to map the structure before performing a full read. This saves tokens and provides immediate orientation.

## 🚀 Procedure

1.  **Index the file**: Run `bash .mwp/md-index.sh <path-to-markdown-file>`.
    *   This outputs a YAML index of headers, line numbers, and content hints.
2.  **Identify Targets**: Review the index to find the specific sections or line ranges related to your task.
3.  **Selective Read**: Use `view` (with `offset` and `limit`) or `sed` to read only the identified sections.

## 🛠️ Usage Examples

```bash
# Get a YAML index (default)
bash .mwp/md-index.sh documents/large-spec.md

# Get a JSON index
bash .mwp/md-index.sh documents/large-spec.md --format json
```
