#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WITH_SECRETS="$REPO_ROOT/scripts/with-secrets.sh"
context="${1:-auto}"

if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst is required to render secret-backed configs." >&2
  exit 1
fi

render_template() {
  local template="$1"
  local output="$2"
  local mode="$3"
  local temp_file

  mkdir -p "$(dirname "$output")"
  temp_file="$(mktemp "${TMPDIR:-/tmp}/render-secret-config.XXXXXX")"

  if ! "$WITH_SECRETS" "$context" -- bash -c 'envsubst < "$1" > "$2"' bash "$template" "$temp_file"; then
    rm -f "$temp_file"
    echo "Failed to render $output" >&2
    exit 1
  fi

  chmod "$mode" "$temp_file"
  mv "$temp_file" "$output"
}

copy_file() {
  local source="$1"
  local output="$2"
  local mode="$3"

  mkdir -p "$(dirname "$output")"
  cp "$source" "$output"
  chmod "$mode" "$output"
}

render_template "$REPO_ROOT/home/dotfiles/codex/config.toml" "$HOME/.codex/config.toml" 600
render_template "$REPO_ROOT/home/dotfiles/opencode/opencode.json" "$HOME/.config/opencode/opencode.json" 600
copy_file "$REPO_ROOT/home/dotfiles/opencode/package.json" "$HOME/.config/opencode/package.json" 644

echo "Rendered secret-backed runtime configs."
