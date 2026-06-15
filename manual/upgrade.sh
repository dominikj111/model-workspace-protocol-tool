#!/bin/bash

set -euo pipefail

BASE_URL="https://raw.githubusercontent.com/dominikj111/model-workspace-protocol-tool/main/manual"

info() { printf "  %s\n" "$1"; }
fail() { printf "  ERROR: %s\n" "$1" >&2; exit 1; }

extract_version() {
  local file=$1
  local version
  version=$(sed -n '1,/^---$/p' "$file" 2>/dev/null \
    | sed -n 's/^[[:space:]]*[Vv]ersion[[:space:]]*:[[:space:]]*//p' \
    | sed -n '1p') || true
  version=${version#\"}
  version=${version%\"}
  version=${version#\'}
  version=${version%\'}
  version=${version#v}
  version=${version#V}
  printf '%s\n' "$version"
}

version_lt() {
  local left=${1#v}
  left=${left#V}
  local right=${2#v}
  right=${right#V}
  local IFS=.
  local -a left_parts right_parts
  read -ra left_parts <<< "$left"
  read -ra right_parts <<< "$right"

  local max=${#left_parts[@]}
  [ "${#right_parts[@]}" -gt "$max" ] && max=${#right_parts[@]}

  local i left_part right_part
  for ((i = 0; i < max; i++)); do
    left_part=${left_parts[i]:-0}
    right_part=${right_parts[i]:-0}
    left_part=${left_part%%[!0-9]*}
    right_part=${right_part%%[!0-9]*}
    [ -z "$left_part" ] && left_part=0
    [ -z "$right_part" ] && right_part=0

    if (( 10#$left_part < 10#$right_part )); then
      return 0
    fi
    if (( 10#$left_part > 10#$right_part )); then
      return 1
    fi
  done

  return 1
}

find_project_root() {
  local dir
  dir=$(pwd)

  if [ "$(basename "$dir")" = ".mwp" ]; then
    dirname "$dir"
    return
  fi

  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.mwp" ]; then
      printf '%s\n' "$dir"
      return
    fi
    dir=$(dirname "$dir")
  done

  return 1
}

run_installer() {
  info "Running mwp-up installer."
  curl --proto '=https' --tlsv1.2 -sSf "$BASE_URL/mwp-up" | sh
}

root=$(find_project_root || true)
if [ -n "$root" ]; then
  cd "$root"
else
  fail "Could not find project root containing .mwp/."
fi

remote_protocol=$(mktemp)
trap 'rm -f "$remote_protocol"' EXIT

if ! curl --proto '=https' --tlsv1.2 -sSf "$BASE_URL/protocol.md" -o "$remote_protocol"; then
  fail "Failed to fetch remote protocol.md."
fi

remote_version=$(extract_version "$remote_protocol")
[ -n "$remote_version" ] || fail "Remote protocol.md has no version in frontmatter."

current_version=""
if [ -f ".mwp/protocol.md" ]; then
  current_version=$(extract_version ".mwp/protocol.md")
fi

if [ -z "$current_version" ]; then
  info "No installed MWP protocol version found."
  run_installer
elif version_lt "$current_version" "$remote_version"; then
  info "Installed MWP version $current_version is older than $remote_version."
  run_installer
else
  info "Installed MWP version $current_version is up to date (remote $remote_version)."
fi
