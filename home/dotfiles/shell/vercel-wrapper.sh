#!/bin/bash
# Vercel CLI wrapper for headless VMs
# Resolves Vercel auth through the shared secret reference registry
# Installed to ~/.local/bin/vercel, shadows ~/.bun/bin/vercel

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/code/dotfiles}"
WITH_SECRETS="$DOTFILES/scripts/with-secrets.sh"
REAL_VERCEL="$HOME/.bun/bin/vercel"

# Default scope to tilt-legal (override with --scope)
if [[ -x "$WITH_SECRETS" ]]; then
  exec "$WITH_SECRETS" vm -- bash -c '
    real="$1"
    shift

    scope_args=()
    has_scope=false
    for arg in "$@"; do
      if [[ "$arg" == "--scope" || "$arg" == --scope=* ]]; then
        has_scope=true
        break
      fi
    done

    if ! $has_scope; then
      scope_args=(--scope tilt-legal)
    fi

    if [[ -n "${VERCEL_TOKEN:-}" ]]; then
      exec "$real" "$@" --token="$VERCEL_TOKEN" "${scope_args[@]}"
    fi

    exec "$real" "$@" "${scope_args[@]}"
  ' bash "$REAL_VERCEL" "$@"
fi

exec "$REAL_VERCEL" "$@"
