#!/usr/bin/env bash
# MWP Context Migration — .mwp-context.md → .mwp-context.yaml
# Usage: bash .mwp/migrate-to-yaml.sh [path]
#
# Converts legacy markdown context files (YAML frontmatter + markdown body) to
# the pure-YAML format (body moved into the `description` key). The original
# .mwp-context.md is deleted only after a valid .mwp-context.yaml was written.
# The reader scripts still accept .mwp-context.md (legacy), so a partially
# migrated tree keeps working.
#
# Idempotent: a second run finds no .md files and reports nothing to migrate.

set -u

TARGET="${1:-.}"
TARGET=$(cd "$TARGET" 2>/dev/null && pwd) || { echo "Error: '$1' not found." >&2; exit 1; }

# Locate project root (nearest .mwp/ above the target; fallback: TARGET)
ROOT="$TARGET"
dir="$TARGET"
while [ "$dir" != "/" ]; do
  if [ -d "$dir/.mwp" ]; then ROOT="$dir"; break; fi
  dir=$(dirname "$dir")
done
cd "$ROOT" || exit 1

# ── .mwpignore filter (grep -vE semantics over full relative paths) ───────────
mwp_filter() {
  local pattern
  pattern=$(grep -v '^[[:space:]]*#' .mwpignore 2>/dev/null \
            | grep -v '^[[:space:]]*$' \
            | tr '\n' '|' | sed 's/|$//')
  if [ -n "$pattern" ]; then grep -vE "$pattern"; else cat; fi
}

# ── YAML sanity check (best effort — python3 yaml when available) ─────────────
validate_yaml() {
  local file="$1"
  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$file" << 'EOF' 2>/dev/null
import sys
try:
    import yaml
except ImportError:
    sys.exit(0)          # no parser available — trust the construction
yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
EOF
}

migrated=0
skipped=0
errors=0

migrate_one() {
  local md="$1"
  local dir
  dir=$(dirname "$md")

  # Conflict: a .yaml or .yml sibling already exists — leave for the author
  if [ -f "$dir/.mwp-context.yaml" ] || [ -f "$dir/.mwp-context.yml" ]; then
    echo "  skip  $md — .mwp-context.yaml/.yml already present"
    skipped=$((skipped + 1))
    return
  fi

  # Extract frontmatter (first pair of --- markers only) and body
  local front="" body=""
  local n=0 line
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" = "---" ]; then
      n=$((n + 1))
      continue
    fi
    if [ "$n" -eq 1 ]; then
      front="$front$line
"
    elif [ "$n" -ge 2 ]; then
      body="$body$line
"
    fi
  done < "$md"

  if [ "$n" -lt 2 ]; then
    echo "  warn  $md — no frontmatter (does not start with ---); not a valid MWP context"
    skipped=$((skipped + 1))
    return
  fi

  # Tabs are forbidden in YAML — convert to spaces
  front=$(printf '%s' "$front" | sed 's/\t/    /g')

  # A legacy verified_paths entry naming the .md file now names the .yaml file
  front=$(printf '%s' "$front" \
    | sed 's/^- \.mwp-context\.md$/- .mwp-context.yaml/; s/^  - \.mwp-context\.md$/  - .mwp-context.yaml/')

  # Strip leading/trailing blank lines only — inner indentation is markdown
  # (lists, code blocks) and must survive verbatim
  body=$(printf '%s' "$body" | awk '
    { lines[NR] = $0 }
    END {
      first = 1; last = NR
      while (first <= NR && lines[first] ~ /^[[:space:]]*$/) first++
      while (last >= 1 && lines[last] ~ /^[[:space:]]*$/) last--
      for (i = first; i <= last; i++) print lines[i]
    }')

  # Description: only when the body is non-empty and not the scaffold stub
  local desc=""
  if [ -n "$body" ] && ! printf '%s' "$body" | grep -q '^<!-- MWP CONTEXT'; then
    desc="$body"
  fi

  {
    echo "schema: 1"
    # Drop a pre-existing schema key (old format never had one; guard anyway)
    printf '%s' "$front" | grep -v '^schema:'
    if [ -n "$desc" ]; then
      echo "description: |"
      printf '%s\n' "$desc" | awk '{ if ($0 ~ /^[[:space:]]*$/) print ""; else print "  " $0 }'
    fi
  } > "$dir/.mwp-context.yaml"

  if validate_yaml "$dir/.mwp-context.yaml"; then
    rm "$md"
    migrated=$((migrated + 1))
    echo "  ok    $md → .mwp-context.yaml"
  else
    echo "  err   $md — generated YAML failed validation; original kept"
    rm -f "$dir/.mwp-context.yaml"
    errors=$((errors + 1))
  fi
}

# ── Collect and migrate ───────────────────────────────────────────────────────
files=$(find . -name ".mwp-context.md" \
  -not -path '*/.git/*' -not -path '*/node_modules/*' \
  -not -path '*/target/*' -not -path '*/dist/*' \
  -not -path '*/.mwp/*' \
  2>/dev/null | sort | mwp_filter)

if [ -z "$files" ]; then
  echo "No .mwp-context.md files found — nothing to migrate."
  exit 0
fi

echo "Migrating .mwp-context.md → .mwp-context.yaml"
echo ""
while IFS= read -r f; do
  [ -n "$f" ] && migrate_one "$f"
done <<< "$files"

echo ""
echo "Done: $migrated migrated, $skipped skipped, $errors errors."
[ "$errors" -gt 0 ] && exit 1
exit 0
