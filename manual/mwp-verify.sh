#!/usr/bin/env bash
# mwp-verify — lightweight verified-references check for MWP manual implementation
#
# Usage: bash .mwp/mwp-verify.sh [TARGET]
#
# TARGET defaults to the current directory.
#
# Behaviour:
#   1. Resolves the nearest .mwp-context.md from TARGET upward.
#   2. Reads `verified_paths:` from its YAML frontmatter (if present) to scope
#      the file hash. Falls back to scanning *.ts, *.tsx, *.js, *.py, *.sh,
#      *.rs, and .mwp-context.md files under TARGET.
#   3. Computes a SHA-256 hash over those files.
#   4. Cache hit  (.mwp/cache/<hash>.ok exists) → exits 0 immediately.
#   5. Cache miss → runs `guards:` commands from the frontmatter (if present),
#      then builtin checks (tsc --noEmit, pytest -k smoke) when the tools exist.
#   6. Pass  → writes .mwp/cache/<hash>.ok, exits 0.
#   7. Fail  → writes .mwp/cache/<hash>.diagnostics.md, appends to
#              .mwp/discoveries.md, prints a visible warning, exits 1.
#
# Integration hint: add to CLAUDE.md or protocol notes —
#   "Before automated write actions (commits, deploys, code changes), run
#    \`bash .mwp/mwp-verify.sh\`. Exit 1 means treat context as read-only."

set -euo pipefail

TARGET="${1:-.}"
TARGET="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"

# ── Locate project root (.mwp/ directory) ─────────────────────────────────────
find_root() {
  local dir="$1"
  while [ "$dir" != "/" ]; do
    [ -d "$dir/.mwp" ] && { echo "$dir"; return 0; }
    dir="$(dirname "$dir")"
  done
  # Fall back to current directory if no .mwp found
  echo "$(pwd)"
}

ROOT="$(find_root "$TARGET")"
CACHE_DIR="$ROOT/.mwp/cache"
DISCOVERIES="$ROOT/.mwp/discoveries.md"

mkdir -p "$CACHE_DIR"

# ── Colors ────────────────────────────────────────────────────────────────────
RED=$(printf '\033[31m')    || RED=""
GREEN=$(printf '\033[32m')  || GREEN=""
YELLOW=$(printf '\033[33m') || YELLOW=""
BOLD=$(printf '\033[1m')    || BOLD=""
NC=$(printf '\033[0m')      || NC=""

ok()   { printf "  ${GREEN}✓${NC}  %s\n" "$1"; }
warn() { printf "  ${YELLOW}⚠${NC}   %s\n" "$1"; }
err()  { printf "  ${RED}✗${NC}  %s\n" "$1" >&2; }

# ── Find nearest .mwp-context.md ──────────────────────────────────────────────
find_context_file() {
  local dir="$1"
  while [ "$dir" != "/" ] && [ "$dir" != "$ROOT/.." ]; do
    [ -f "$dir/.mwp-context.md" ] && { echo "$dir/.mwp-context.md"; return 0; }
    dir="$(dirname "$dir")"
  done
  echo ""
}

CONTEXT_FILE="$(find_context_file "$TARGET")"

# ── Parse verified_paths from YAML frontmatter ────────────────────────────────
# Reads lines between the first two '---' markers and extracts verified_paths entries.
parse_verified_paths() {
  local file="$1"
  local in_front=0 in_verified=0
  local paths=()
  while IFS= read -r line; do
    if [ "$in_front" -eq 0 ] && [ "$line" = "---" ]; then
      in_front=1; continue
    fi
    [ "$in_front" -eq 0 ] && break
    [ "$line" = "---" ] && break
    if echo "$line" | grep -q "^verified_paths:"; then
      in_verified=1; continue
    fi
    if [ "$in_verified" -eq 1 ]; then
      if echo "$line" | grep -q "^  - "; then
        path="$(echo "$line" | sed 's/^  - //' | tr -d ' ')"
        paths+=("$path")
      else
        in_verified=0
      fi
    fi
  done < "$file"
  printf '%s\n' "${paths[@]+"${paths[@]}"}"
}

# ── Parse guards cmds from YAML frontmatter ───────────────────────────────────
parse_guard_cmds() {
  local file="$1"
  local in_front=0 in_guards=0 in_entry=0
  while IFS= read -r line; do
    if [ "$in_front" -eq 0 ] && [ "$line" = "---" ]; then
      in_front=1; continue
    fi
    [ "$in_front" -eq 0 ] && break
    [ "$line" = "---" ] && break
    if echo "$line" | grep -q "^guards:"; then
      in_guards=1; continue
    fi
    if [ "$in_guards" -eq 1 ]; then
      if echo "$line" | grep -q "^  - cmd:"; then
        cmd="$(echo "$line" | sed 's/^  - cmd: //' | tr -d ' ')"
        # Handle multi-word commands (sed leaves them intact, just strip leading spaces)
        cmd="$(echo "$line" | sed 's/^  - cmd: //')"
        echo "$cmd"
      elif echo "$line" | grep -q "^[a-z]"; then
        in_guards=0
      fi
    fi
  done < "$file"
}

# ── Collect files for hashing ─────────────────────────────────────────────────
HASH_FILES=()

if [ -n "$CONTEXT_FILE" ]; then
  mapfile -t VP < <(parse_verified_paths "$CONTEXT_FILE" 2>/dev/null || true)
fi

if [ "${#VP[@]:-0}" -gt 0 ] 2>/dev/null; then
  # Use declared verified_paths, resolved relative to context file's directory
  CTX_DIR="$(dirname "$CONTEXT_FILE")"
  for vp in "${VP[@]}"; do
    candidate="$CTX_DIR/$vp"
    if [ -d "$candidate" ]; then
      while IFS= read -r f; do HASH_FILES+=("$f"); done \
        < <(find "$candidate" -type f 2>/dev/null | sort)
    elif [ -f "$candidate" ]; then
      HASH_FILES+=("$candidate")
    fi
  done
else
  # Default: scan common source extensions under TARGET
  while IFS= read -r f; do HASH_FILES+=("$f"); done \
    < <(find "$TARGET" -type f \
        \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" \
           -o -name "*.py" -o -name "*.sh" -o -name "*.rs" \
           -o -name ".mwp-context.md" \) \
        ! -path "*/.mwp/*" ! -path "*/node_modules/*" \
        ! -path "*/.git/*" ! -path "*/dist/*" ! -path "*/target/*" \
        | sort)
fi

if [ "${#HASH_FILES[@]}" -eq 0 ]; then
  warn "No files found to hash under $TARGET — skipping verification"
  exit 0
fi

# ── Compute hash ──────────────────────────────────────────────────────────────
if command -v sha256sum >/dev/null 2>&1; then
  HASH=$(printf '%s\n' "${HASH_FILES[@]}" | xargs sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1)
elif command -v shasum >/dev/null 2>&1; then
  HASH=$(printf '%s\n' "${HASH_FILES[@]}" | xargs shasum -a 256 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
else
  warn "No sha256sum or shasum found — skipping verification"
  exit 0
fi

OK_FILE="$CACHE_DIR/$HASH.ok"
DIAG_FILE="$CACHE_DIR/$HASH.diagnostics.md"

# ── Cache hit ─────────────────────────────────────────────────────────────────
if [ -f "$OK_FILE" ]; then
  ok "MWP verification cache hit ($HASH)"
  exit 0
fi

# ── Cache miss — run checks ───────────────────────────────────────────────────
printf "  ${BOLD}MWP verification${NC} — running checks for %s\n" "$TARGET"

{
  echo "# MWP Verification Diagnostics"
  echo ""
  echo "- target: $TARGET"
  echo "- hash: $HASH"
  echo "- timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "- context_file: ${CONTEXT_FILE:-none}"
  echo ""
} > "$DIAG_FILE"

FAILED=0

run_check() {
  local label="$1"
  shift
  printf "  Running: %s\n" "$label"
  if "$@" >> "$DIAG_FILE" 2>&1; then
    ok "$label"
  else
    err "$label failed (see $DIAG_FILE)"
    FAILED=1
  fi
}

# Guards from frontmatter
if [ -n "$CONTEXT_FILE" ]; then
  while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    # shellcheck disable=SC2086
    run_check "$cmd" sh -c "$cmd"
  done < <(parse_guard_cmds "$CONTEXT_FILE" 2>/dev/null || true)
fi

# Builtin checks — only when the tool exists and no guards were declared
if [ -z "$CONTEXT_FILE" ] || ! grep -q "^guards:" "$CONTEXT_FILE" 2>/dev/null; then
  if command -v tsc >/dev/null 2>&1; then
    run_check "tsc --noEmit" tsc --noEmit
  fi
  if command -v pytest >/dev/null 2>&1; then
    run_check "pytest -k smoke" pytest -k smoke
  fi
fi

# ── Outcome ───────────────────────────────────────────────────────────────────
if [ "$FAILED" -eq 0 ]; then
  touch "$OK_FILE"
  ok "MWP verification passed ($HASH)"
  exit 0
else
  # Append to discoveries so the failure survives session compaction
  {
    echo ""
    echo "## Verification failure — $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
    echo "- target: $TARGET"
    echo "- hash: $HASH"
    echo "- diagnostics: .mwp/cache/$HASH.diagnostics.md"
    echo ""
    echo "**Context is read-only until guards pass.**"
    echo "Do not commit, deploy, or apply automated code changes until resolved."
    echo ""
  } >> "$DISCOVERIES"

  printf "\n"
  printf "  ${RED}${BOLD}MWP verification FAILED${NC}\n"
  printf "  Context is ${BOLD}read-only${NC} — do not apply automated changes.\n"
  printf "  Diagnostics: .mwp/cache/%s.diagnostics.md\n" "$HASH"
  printf "  Failure logged to: .mwp/discoveries.md\n\n"
  exit 1
fi
