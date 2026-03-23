#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WITH_SECRETS="$REPO_ROOT/scripts/with-secrets.sh"

export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.bun/bin:$PATH"

install_if_missing() {
  local target="$1"
  local name="$2"
  local install_cmd="$3"

  if [[ ! -x "$target" ]]; then
    echo "Installing $name..."
    bash -lc "$install_cmd"
  fi
}

install_if_missing "$HOME/.local/bin/claude" "Claude Code" "curl -fsSL https://claude.ai/install.sh | bash"
install_if_missing "$HOME/.opencode/bin/opencode" "OpenCode" "curl -fsSL https://opencode.ai/install | bash"
install_if_missing "$HOME/.bun/bin/bun" "Bun" "curl -fsSL https://bun.sh/install | bash"

if [[ -x "$HOME/.bun/bin/bun" ]]; then
  if ! "$HOME/.bun/bin/bun" pm ls -g 2>/dev/null | grep -q "turbo@"; then
    echo "Installing Turborepo..."
    "$HOME/.bun/bin/bun" add -g turbo@latest
  fi

  if ! "$HOME/.bun/bin/bun" pm ls -g 2>/dev/null | grep -q "vercel@"; then
    echo "Installing Vercel CLI..."
    "$HOME/.bun/bin/bun" add -g vercel
  fi
fi

if ! command -v codex >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  echo "Installing Codex..."
  npm install -g @openai/codex
fi

echo "Rendering secret-backed runtime configs..."
"$REPO_ROOT/scripts/render-secret-configs.sh"

VERCEL_BYPASS=""
if [[ -x "$WITH_SECRETS" ]]; then
  VERCEL_BYPASS="$("$WITH_SECRETS" auto --no-masking -- printenv VERCEL_BYPASS_SECRET 2>/dev/null || true)"
fi

if [[ -x "$HOME/.local/bin/claude" ]]; then
  echo "Configuring Claude MCP servers..."
  "$HOME/.local/bin/claude" mcp remove -s user deepwiki 2>/dev/null || true
  "$HOME/.local/bin/claude" mcp add -s user -t http deepwiki https://mcp.deepwiki.com/mcp
  "$HOME/.local/bin/claude" mcp remove -s user cubitt 2>/dev/null || true
  "$HOME/.local/bin/claude" mcp add -s user -t http cubitt https://cubitt.tilt.legal/mcp
  "$HOME/.local/bin/claude" mcp remove -s user cubitt-canary 2>/dev/null || true

  if [[ -n "$VERCEL_BYPASS" ]]; then
    "$HOME/.local/bin/claude" mcp add -s user -t http cubitt-canary https://cubitt-env-canary-tilt-legal.vercel.app/mcp \
      -H "x-vercel-protection-bypass: $VERCEL_BYPASS"
  else
    "$HOME/.local/bin/claude" mcp add -s user -t http cubitt-canary https://cubitt-env-canary-tilt-legal.vercel.app/mcp
  fi
fi

echo ""
echo "External AI CLI setup complete."
echo "Runtime AI configs and CLI installs are now aligned with the repo state in:"
echo "  $REPO_ROOT/home/dotfiles"
