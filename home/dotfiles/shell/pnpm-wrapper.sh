#!/bin/bash
# pnpm wrapper for secret-backed GitHub Packages auth on all machines.
# Runs pnpm with GH_NPM_TOKEN resolved through the shared secret registry.
# Installed to ~/.local/bin/pnpm, shadows nix-provided pnpm.

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/code/dotfiles}"
WITH_SECRETS="$DOTFILES/scripts/with-secrets.sh"

# Find the real (non-wrapper) pnpm binary
REAL_PNPM=""
for p in "$HOME/.nix-profile/bin/pnpm" "/etc/profiles/per-user/$(whoami)/bin/pnpm" "/run/current-system/sw/bin/pnpm"; do
  if [[ -x "$p" ]]; then
    REAL_PNPM="$p"
    break
  fi
done

if [[ -z "$REAL_PNPM" ]]; then
  echo "Error: could not find nix-provided pnpm" >&2
  exit 1
fi

if [[ -x "$WITH_SECRETS" ]]; then
  exec "$WITH_SECRETS" auto -- "$REAL_PNPM" "$@"
fi

exec "$REAL_PNPM" "$@"
