#!/bin/bash
# pnpm wrapper for headless VMs
# Exports GH_NPM_TOKEN from 1Password for private @tilt-legal packages
# Installed to ~/.local/bin/pnpm, shadows nix-provided pnpm

# Load OP service account token if not in env
if [[ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]] && [[ -f "$HOME/.config/op/service-account-token" ]]; then
  export OP_SERVICE_ACCOUNT_TOKEN=$(cat "$HOME/.config/op/service-account-token")
fi

# Fetch GitHub NPM token from 1Password
if [[ -n "$OP_SERVICE_ACCOUNT_TOKEN" ]] && [[ -z "$GH_NPM_TOKEN" ]]; then
  export GH_NPM_TOKEN=$(op read "op://VM/GH_CLASSIC_PAT/token" 2>/dev/null)
fi

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

exec "$REAL_PNPM" "$@"
