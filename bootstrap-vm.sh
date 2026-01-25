#!/bin/bash
set -e

echo "=== OpenCode VM Bootstrap ==="
echo ""

if [[ $EUID -eq 0 ]]; then
  echo "Don't run as root. Run as your normal user."
  exit 1
fi

if [[ -z "$TS_AUTHKEY" ]]; then
  echo "TS_AUTHKEY not set."
  echo ""
  echo "Get it from 1Password and run:"
  echo "  export TS_AUTHKEY='tskey-auth-...'"
  echo "  ./bootstrap-vm.sh"
  echo ""
  echo "Or run with inline:"
  echo "  TS_AUTHKEY='tskey-auth-...' ./bootstrap-vm.sh"
  exit 1
fi

echo "[1/7] Installing Nix..."
if ! command -v nix &>/dev/null; then
  sh <(curl -L https://nixos.org/nix/install) --daemon
  echo "Nix installed. Please restart your shell and run this script again."
  exit 0
else
  echo "Nix already installed."
fi

echo ""
echo "[2/7] Installing Node.js..."
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
else
  echo "Node.js already installed: $(node --version)"
fi

echo ""
echo "[3/7] Installing OpenCode CLI..."
if [[ ! -x "$HOME/.opencode/bin/opencode" ]]; then
  curl -fsSL https://opencode.ai/install | bash
else
  echo "OpenCode CLI already installed."
fi

echo ""
echo "[4/7] Installing OpenChamber..."
if ! command -v openchamber &>/dev/null; then
  npm install -g @openchamber/web
else
  echo "OpenChamber already installed: $(openchamber --version 2>/dev/null || echo 'installed')"
fi

echo ""
echo "[5/7] Cloning dotfiles..."
if [[ ! -d "$HOME/dotfiles" ]]; then
  git clone git@github.com:damian-dp/dotfiles.git "$HOME/dotfiles"
else
  echo "Dotfiles already cloned. Pulling latest..."
  git -C "$HOME/dotfiles" pull
fi

echo ""
echo "[6/7] Authenticating Tailscale..."
if tailscale status &>/dev/null; then
  echo "Tailscale already authenticated."
else
  sudo tailscale up --authkey="$TS_AUTHKEY"
  echo "Tailscale authenticated."
fi

echo ""
echo "[7/7] Applying home-manager config..."
nix run home-manager -- switch --flake "$HOME/dotfiles#damian@linux"

echo ""
echo "=== Verifying setup ==="
echo ""

TS_HOSTNAME=$(tailscale status --self --json 2>/dev/null | jq -r '.Self.DNSName' | sed 's/\.$//')
echo "Tailscale hostname: $TS_HOSTNAME"
echo ""
echo "=== Setup Complete ==="
echo ""
echo "OpenChamber will start automatically on next login."
echo "Or start now with: systemctl --user start openchamber"
echo ""
echo "Access from:"
echo "  - Web UI: https://$TS_HOSTNAME"
echo "  - Mac:    open https://$TS_HOSTNAME"
echo ""
echo "For TUI mode, SSH in and run: opencode"
