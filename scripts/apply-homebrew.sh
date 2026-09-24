#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ "$(uname -s)" != Darwin ]]; then
  echo "Homebrew activation is only supported on macOS." >&2
  exit 1
fi

TARGET_HOST="${1:-$(scutil --get LocalHostName)}"
case "$TARGET_HOST" in
  Damian-Studio|Damian-MBP)
    ;;
  *)
    echo "Usage: $0 [Damian-Studio|Damian-MBP]" >&2
    exit 2
    ;;
esac

# Keep the new Homebrew closure rooted even without a full system switch.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
mkdir -p "$STATE_DIR"
nix build "$REPO_ROOT#darwinConfigurations.$TARGET_HOST.system" \
  --out-link "$STATE_DIR/homebrew-system"

# Apply only nix-homebrew's setup, without brew bundle or app cleanup.
ACTIVATION="$(nix eval --raw \
  "$REPO_ROOT#darwinConfigurations.$TARGET_HOST.config.system.activationScripts.setup-homebrew.text")"
/bin/bash -euo pipefail -c "$ACTIVATION"

EXPECTED_VERSION="$(nix eval --raw \
  "$REPO_ROOT#darwinConfigurations.$TARGET_HOST.config.nix-homebrew.package.version")"
ACTUAL_VERSION="$(/opt/homebrew/bin/brew --version)"
printf '%s\n' "$ACTUAL_VERSION"
if [[ "${ACTUAL_VERSION%%$'\n'*}" != "Homebrew $EXPECTED_VERSION" ]]; then
  echo "Expected Homebrew $EXPECTED_VERSION after activation." >&2
  exit 1
fi
