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

exec "$HOME/.nix-profile/bin/pnpm" "$@"
