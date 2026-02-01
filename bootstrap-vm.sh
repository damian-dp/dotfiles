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

echo "[1/6] Installing Nix..."
if ! command -v nix &>/dev/null; then
  sh <(curl -L https://nixos.org/nix/install) --daemon
  echo "Nix installed. Please restart your shell and run this script again."
  exit 0
else
  echo "Nix already installed."
fi

echo ""
echo "[2/6] Installing OpenCode CLI..."
if [[ ! -x "$HOME/.opencode/bin/opencode" ]]; then
  curl -fsSL https://opencode.ai/install | bash
else
  echo "OpenCode CLI already installed."
fi

echo ""
echo "[3/6] Cloning dotfiles..."
if [[ ! -d "$HOME/dotfiles" ]]; then
  git clone git@github.com:damian-dp/dotfiles.git "$HOME/dotfiles"
else
  echo "Dotfiles already cloned. Pulling latest..."
  git -C "$HOME/dotfiles" pull
fi

echo ""
echo "[4/6] Authenticating Tailscale..."
if tailscale status &>/dev/null; then
  echo "Tailscale already authenticated."
else
  sudo tailscale up --authkey="$TS_AUTHKEY"
  echo "Tailscale authenticated."
fi

echo ""
echo "[5/6] Setting up OpenCode server password..."
CREDS_DIR="$HOME/.config/opencode/credentials"
if [[ ! -f "$CREDS_DIR/server_password" ]]; then
  mkdir -p "$CREDS_DIR"
  read -sp "Enter password for OpenCode server: " OC_PASSWORD
  echo ""
  echo "$OC_PASSWORD" > "$CREDS_DIR/server_password"
  chmod 600 "$CREDS_DIR/server_password"
  echo "Password saved."
else
  echo "Password already configured."
fi

echo ""
echo "[6/6] Applying home-manager config..."
nix run home-manager -- switch --flake "$HOME/dotfiles#damian@linux"

# Enable lingering so services run without login
loginctl enable-linger "$USER"

echo ""
echo "=== Verifying setup ==="
echo ""

TS_HOSTNAME=$(tailscale status --self --json 2>/dev/null | jq -r '.Self.DNSName' | sed 's/\.$//')
echo "Tailscale hostname: $TS_HOSTNAME"
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Start OpenCode server now with:"
echo "  systemctl --user start opencode"
echo ""
echo "Access from your Mac (via Tailscale):"
echo "  http://$TS_HOSTNAME:4096"
echo ""
echo "For local TUI mode, SSH in and run: opencode"
