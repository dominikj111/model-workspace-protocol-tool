#!/bin/bash
# MWP Concat Context — concatenates the context cascade from project root to target
# Usage: bash .mwp/concat-context.sh <target-file-or-directory>
# Output to stdout. Run ONCE per chat session when the target is known.
#
# Per-directory lookup order: .mwp-context.yaml → .mwp-context.yml →
# .mwp-context.md (legacy). For YAML files only the `description` key is
# rendered — it holds the markdown prose; the other keys are metadata for the
# mapper. Legacy .md files are emitted whole.

TARGET="${1:-.}"

# Resolve target directory
if [ -f "$TARGET" ]; then
  TARGET_DIR=$(cd "$(dirname "$TARGET")" && pwd)
elif [ -d "$TARGET" ]; then
  TARGET_DIR=$(cd "$TARGET" && pwd)
else
  echo "Error: '$TARGET' not found." >&2
  exit 1
fi

# Find project root — nearest ancestor with .mwp, fallback to git root or CWD
ROOT=""
dir="$TARGET_DIR"
while [ "$dir" != "/" ]; do
  if [ -d "$dir/.mwp" ] || [ -f "$dir/.mwp" ]; then
    ROOT="$dir"
    break
  fi
  dir=$(dirname "$dir")
done
[ -z "$ROOT" ] && ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Build ordered directory list: root → target
rel_path="${TARGET_DIR#"$ROOT"}"
rel_path="${rel_path#/}"

dirs=("$ROOT")
current="$ROOT"
IFS='/' read -ra parts <<< "$rel_path"
for part in "${parts[@]}"; do
  [ -z "$part" ] && continue
  current="$current/$part"
  dirs+=("$current")
done

# resolve_context <dir> — echoes the context file to use (yaml → yml → md), or nothing
resolve_context() {
  local d="$1"
  if [ -f "$d/.mwp-context.yaml" ]; then
    if [ -f "$d/.mwp-context.yml" ]; then
      echo "WARN: both .mwp-context.yaml and .mwp-context.yml in $d — .yaml wins" >&2
    fi
    [ -f "$d/.mwp-context.md" ] && \
      echo "WARN: stale .mwp-context.md beside $d/.mwp-context.yaml — run migrate-to-yaml.sh" >&2
    echo "$d/.mwp-context.yaml"
  elif [ -f "$d/.mwp-context.yml" ]; then
    [ -f "$d/.mwp-context.md" ] && \
      echo "WARN: stale .mwp-context.md beside $d/.mwp-context.yml — run migrate-to-yaml.sh" >&2
    echo "$d/.mwp-context.yml"
  elif [ -f "$d/.mwp-context.md" ]; then
    echo "$d/.mwp-context.md"
  fi
}

# extract_description <yaml-file> — prints the `description` block scalar body
# (canonical 2-space block indentation; any key change ends the block)
extract_description() {
  local file="$1"
  local in_desc=0 line rest
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$in_desc" -eq 0 ]; then
      case "$line" in
        description:*)
          in_desc=1
          rest="${line#description:}"
          rest="${rest# }"
          case "$rest" in
            '|'*|'>'*|'') ;;                       # block scalar marker
            *) printf '%s\n' "$rest" ;;            # inline scalar
          esac
          ;;
      esac
    else
      case "$line" in
        '  '*|$'\t'*) printf '%s\n' "${line#  }" ;;
        '') printf '\n' ;;                         # blank line inside block — emit as-is
        *) in_desc=0 ;;
      esac
    fi
  done < "$file"
}

# Concatenate context files in root → target order
found=0
for d in "${dirs[@]}"; do
  ctx="$(resolve_context "$d")"
  [ -z "$ctx" ] && continue
  rel="${d#"$ROOT"}"
  rel="${rel#/}"
  [ -z "$rel" ] && rel="."
  echo "<!-- context: $rel/$(basename "$ctx") -->"
  case "$ctx" in
    *.md) cat "$ctx" ;;
    *)    extract_description "$ctx" ;;
  esac
  echo ""
  found=$((found + 1))
done

if [ "$found" -eq 0 ]; then
  echo "<!-- No context files found in cascade to: $TARGET -->"
  echo "<!-- Consider creating .mwp-context.yaml files along the path (see protocol.md) -->"
fi
