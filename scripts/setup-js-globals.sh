#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" == "Darwin" ]]; then
  PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
else
  PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
fi

export PNPM_HOME
export PATH="$HOME/.local/bin:$PNPM_HOME:$PATH"

REAL_PNPM=""
for p in "$HOME/.local/bin/pnpm" "$HOME/.nix-profile/bin/pnpm" "/etc/profiles/per-user/$(whoami)/bin/pnpm" "/run/current-system/sw/bin/pnpm"; do
  if [[ -x "$p" ]]; then
    REAL_PNPM="$p"
    break
  fi
done

if [[ -z "$REAL_PNPM" ]]; then
  echo "pnpm is required to install global JS CLIs." >&2
  exit 1
fi

mkdir -p "$PNPM_HOME"

packages=(
  "@openai/codex@latest"
  "turbo@latest"
  "vercel@latest"
  "@tailwindcss/cli@latest"
  "portless@latest"
)

echo "Installing pnpm-managed global JS CLIs..."
"$REAL_PNPM" add -g "${packages[@]}"

echo ""
echo "Installed pnpm globals:"
for cmd in codex turbo vercel tailwindcss portless; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  $cmd -> $(command -v "$cmd")"
  else
    echo "  $cmd -> missing from PATH"
  fi
done
