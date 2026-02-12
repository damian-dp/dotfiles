#!/bin/bash
set -e

# =============================================================================
# OpenCode VM Bootstrap
# =============================================================================
# Sets up a fresh Linux VM as a remote dev environment with:
#   - 1Password CLI (service account for headless secret management)
#   - Tailscale (mesh VPN for remote access)
#   - Nix + home-manager (declarative config from dotfiles)
#   - OpenCode web server (AI coding assistant)
#   - SSH key for GitHub auth + git commit signing
#
# PREREQUISITES (do these once from your Mac):
#   1. Create a vault called "VM" in 1Password
#   2. Add these items to the VM vault:
#      - "TS_AUTH_KEY"   → field "credential"  (Tailscale auth key)
#      - "GH_SSH_KEY"    → SSH key item        (your ed25519 key for GitHub)
#      - "GH_MASTER_PAT" → field "token"       (GitHub PAT with repo scope)
#   3. Create a Service Account (1Password Settings > Developer > Service Accounts)
#      - Grant read_items access to the VM vault only
#      - Save the token (starts with ops_)
#
# USAGE:
#   OP_SERVICE_ACCOUNT_TOKEN='ops_...' ./bootstrap-vm.sh
# =============================================================================

echo "=== OpenCode VM Bootstrap ==="
echo ""

# -----------------------------------------------------------------------------
# Preflight checks
# -----------------------------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
  echo "Don't run as root. Run as your normal user."
  exit 1
fi

if [[ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]]; then
  echo "OP_SERVICE_ACCOUNT_TOKEN not set."
  echo ""
  echo "Create a 1Password Service Account with access to your VM vault,"
  echo "then run:"
  echo "  OP_SERVICE_ACCOUNT_TOKEN='ops_...' ./bootstrap-vm.sh"
  exit 1
fi

export OP_SERVICE_ACCOUNT_TOKEN

# -----------------------------------------------------------------------------
# [1/8] Install prerequisites
# -----------------------------------------------------------------------------
echo "[1/8] Installing prerequisites..."
NEEDS_INSTALL=()
for cmd in git curl jq tar; do
  if ! command -v "$cmd" &>/dev/null; then
    NEEDS_INSTALL+=("$cmd")
  fi
done

if [[ ${#NEEDS_INSTALL[@]} -gt 0 ]]; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq "${NEEDS_INSTALL[@]}"
  echo "Installed: ${NEEDS_INSTALL[*]}"
else
  echo "Prerequisites already installed."
fi

# -----------------------------------------------------------------------------
# [2/8] Install 1Password CLI
# -----------------------------------------------------------------------------
echo ""
echo "[2/8] Installing 1Password CLI..."
if ! command -v op &>/dev/null; then
  curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
    sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
    sudo tee /etc/apt/sources.list.d/1password.list
  sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
  curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
    sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
  sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
  curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
    sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
  sudo apt-get update -qq
  sudo apt-get install -y -qq 1password-cli
  echo "1Password CLI installed."
else
  echo "1Password CLI already installed."
fi

# -----------------------------------------------------------------------------
# [3/8] Verify 1Password authentication
# -----------------------------------------------------------------------------
echo ""
echo "[3/8] Verifying 1Password service account..."
if ! op vault list --format=json 2>/dev/null | jq -e '.[] | select(.name == "VM")' >/dev/null 2>&1; then
  echo "ERROR: Cannot access 'VM' vault. Check your service account token and vault permissions."
  exit 1
fi
echo "Authenticated. VM vault accessible."

# -----------------------------------------------------------------------------
# [4/8] Install Tailscale + authenticate
# -----------------------------------------------------------------------------
echo ""
echo "[4/8] Setting up Tailscale..."
if ! command -v tailscale &>/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
  echo "Tailscale installed."
else
  echo "Tailscale already installed."
fi

if ! tailscale status &>/dev/null; then
  TS_AUTHKEY=$(op read "op://VM/TS_AUTH_KEY/credential")
  sudo tailscale up --authkey="$TS_AUTHKEY"
  echo "Tailscale authenticated."
else
  echo "Tailscale already connected."
fi

# -----------------------------------------------------------------------------
# [5/8] Install Nix
# -----------------------------------------------------------------------------
echo ""
echo "[5/8] Installing Nix..."
if ! command -v nix &>/dev/null; then
  sh <(curl -L https://nixos.org/nix/install) --daemon
  echo ""
  echo "Nix installed. Please restart your shell and run this script again."
  echo "  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  echo "  OP_SERVICE_ACCOUNT_TOKEN='$OP_SERVICE_ACCOUNT_TOKEN' ./bootstrap-vm.sh"
  exit 0
else
  echo "Nix already installed."
fi

# Ensure flakes and nix-command are enabled
if ! grep -q "experimental-features" /etc/nix/nix.conf 2>/dev/null; then
  echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf >/dev/null
  sudo systemctl restart nix-daemon
  echo "Enabled flakes and nix-command."
fi

# -----------------------------------------------------------------------------
# [6/8] Clone dotfiles + authenticate GitHub
# -----------------------------------------------------------------------------
echo ""
echo "[6/8] Setting up GitHub + cloning dotfiles..."

# Use gh via nix run (avoids nix profile conflict with home-manager)
GH_CMD="nix run nixpkgs#gh --"

# Authenticate gh with token from 1Password
if ! $GH_CMD auth status &>/dev/null 2>&1; then
  GH_TOKEN=$(op read "op://VM/GH_MASTER_PAT/token")
  echo "$GH_TOKEN" | $GH_CMD auth login --with-token
  echo "GitHub CLI authenticated."
else
  echo "GitHub CLI already authenticated."
fi

# Configure git to use gh for HTTPS auth
$GH_CMD auth setup-git

if [[ ! -d "$HOME/dotfiles" ]]; then
  git clone https://github.com/damian-dp/dotfiles.git "$HOME/dotfiles"
  echo "Dotfiles cloned."
else
  echo "Dotfiles already cloned. Pulling latest..."
  git -C "$HOME/dotfiles" pull
fi

# -----------------------------------------------------------------------------
# [7/8] Set up SSH key (for GitHub SSH + git commit signing)
# -----------------------------------------------------------------------------
echo ""
echo "[7/8] Setting up SSH key..."
SSH_KEY="$HOME/.ssh/id_ed25519_signing"
if [[ ! -f "$SSH_KEY" ]]; then
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  op read "op://VM/GH_SSH_KEY/private key" --out-file "$SSH_KEY" --force
  chmod 600 "$SSH_KEY"
  ssh-keygen -y -f "$SSH_KEY" > "${SSH_KEY}.pub"
  chmod 644 "${SSH_KEY}.pub"
  echo "SSH signing key extracted from 1Password."
else
  echo "SSH key already exists."
fi

# Add to ssh-agent for this session
eval "$(ssh-agent -s)" >/dev/null 2>&1
ssh-add "$SSH_KEY" 2>/dev/null

# Switch dotfiles remote to SSH now that key is available
git -C "$HOME/dotfiles" remote set-url origin git@github.com:damian-dp/dotfiles.git 2>/dev/null || true

# -----------------------------------------------------------------------------
# [8/8] Apply home-manager config
# -----------------------------------------------------------------------------
echo ""
echo "[8/8] Applying home-manager config..."

nix run home-manager -- switch -b backup --flake "$HOME/dotfiles#damian@linux"

# Enable lingering so systemd user services run without an active login session
loginctl enable-linger "$USER"

# Start OpenCode server
systemctl --user start opencode 2>/dev/null || true

# =============================================================================
# Done
# =============================================================================
echo ""
echo "=== Verifying setup ==="
echo ""

TS_HOSTNAME=$(tailscale status --self --json 2>/dev/null | jq -r '.Self.DNSName' | sed 's/\.$//')
echo "Tailscale hostname: $TS_HOSTNAME"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "OpenCode web UI (from any Tailscale device):"
echo "  http://$TS_HOSTNAME:4096"
echo ""
echo "Attach from terminal:"
echo "  opencode attach http://$TS_HOSTNAME:4096"
echo ""
echo "SSH into VM:"
echo "  ssh damian@$TS_HOSTNAME"
