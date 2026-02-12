#!/bin/bash
# Vercel CLI wrapper for headless VMs
# Fetches token from 1Password and passes --token flag to CLI
# Installed to ~/.local/bin/vercel, shadows ~/.bun/bin/vercel

set -e

# Load OP service account token if not in env
if [[ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]] && [[ -f "$HOME/.config/op/service-account-token" ]]; then
  export OP_SERVICE_ACCOUNT_TOKEN=$(cat "$HOME/.config/op/service-account-token")
fi

# Fetch Vercel token from 1Password
if [[ -n "$OP_SERVICE_ACCOUNT_TOKEN" ]] && [[ -z "$VERCEL_TOKEN" ]]; then
  VERCEL_TOKEN=$(op read "op://VM/VERCEL_TOKEN/token" 2>/dev/null)
fi

if [[ -n "$VERCEL_TOKEN" ]]; then
  exec "$HOME/.bun/bin/vercel" --token="$VERCEL_TOKEN" "$@"
else
  exec "$HOME/.bun/bin/vercel" "$@"
fi
