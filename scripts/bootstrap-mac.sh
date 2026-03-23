#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOST="${1:-Damian-Studio}"

case "$HOST" in
  Damian-Studio|Damian-MBP)
    ;;
  *)
    echo "Usage: $0 [Damian-Studio|Damian-MBP]" >&2
    exit 2
    ;;
esac

echo "==> Applying nix-darwin host: $HOST"
sudo -H nix run github:nix-darwin/nix-darwin/master#darwin-rebuild -- switch --flake "$REPO_ROOT#$HOST"

echo ""
echo "==> Installing external AI CLIs"
"$REPO_ROOT/scripts/setup-ai-clis.sh"

echo ""
echo "==> Installing pnpm-managed global JS CLIs"
"$REPO_ROOT/scripts/setup-js-globals.sh"

echo ""
echo "==> Verifying macOS workstation state"
"$REPO_ROOT/scripts/verify-machine.sh" mac
