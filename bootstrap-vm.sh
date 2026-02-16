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

OP_TOKEN_FILE="$HOME/.config/op/service-account-token"

# Load token from disk if not provided via env
if [[ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]] && [[ -f "$OP_TOKEN_FILE" ]]; then
  OP_SERVICE_ACCOUNT_TOKEN=$(cat "$OP_TOKEN_FILE")
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

# Persist token to disk for future use (shell, scripts, etc.)
if [[ ! -f "$OP_TOKEN_FILE" ]]; then
  mkdir -p "$(dirname "$OP_TOKEN_FILE")"
  echo "$OP_SERVICE_ACCOUNT_TOKEN" > "$OP_TOKEN_FILE"
  chmod 600 "$OP_TOKEN_FILE"
  echo "Service account token saved to $OP_TOKEN_FILE"
fi

# -----------------------------------------------------------------------------
# [1/10] Install prerequisites
# -----------------------------------------------------------------------------
echo "[1/10] Installing prerequisites..."
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
# [2/10] Install 1Password CLI
# -----------------------------------------------------------------------------
echo ""
echo "[2/10] Installing 1Password CLI..."
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
# [3/10] Verify 1Password authentication
# -----------------------------------------------------------------------------
echo ""
echo "[3/10] Verifying 1Password service account..."
if ! op vault list --format=json 2>/dev/null | jq -e '.[] | select(.name == "VM")' >/dev/null 2>&1; then
  echo "ERROR: Cannot access 'VM' vault. Check your service account token and vault permissions."
  exit 1
fi
echo "Authenticated. VM vault accessible."

# -----------------------------------------------------------------------------
# [4/10] Install Tailscale + authenticate
# -----------------------------------------------------------------------------
echo ""
echo "[4/10] Setting up Tailscale..."
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
# [5/10] Install Nix
# -----------------------------------------------------------------------------
echo ""
echo "[5/10] Installing Nix..."
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
# [6/10] Set up SSH key (for GitHub SSH + git commit signing)
# -----------------------------------------------------------------------------
echo ""
echo "[6/10] Setting up SSH key..."
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

# -----------------------------------------------------------------------------
# [7/10] Clone dotfiles via SSH
# -----------------------------------------------------------------------------
echo ""
echo "[7/10] Cloning dotfiles..."
if [[ ! -d "$HOME/code/dotfiles" ]]; then
  git clone git@github.com:damian-dp/dotfiles.git "$HOME/code/dotfiles"
  echo "Dotfiles cloned."
else
  echo "Dotfiles already cloned. Pulling latest..."
  git -C "$HOME/code/dotfiles" pull
fi

# -----------------------------------------------------------------------------
# [8/10] Apply home-manager config
# -----------------------------------------------------------------------------
echo ""
echo "[8/10] Applying home-manager config..."

nix run home-manager -- switch -b backup --flake "$HOME/code/dotfiles#damian@linux"

# Verify Vercel CLI access (token loaded from 1Password on demand via zshrc wrapper)
if [ -x "$HOME/.bun/bin/vercel" ]; then
  VERCEL_TOKEN_VAL=$(op read "op://VM/VERCEL_TOKEN/token" 2>/dev/null)
  if [[ -n "$VERCEL_TOKEN_VAL" ]]; then
    # Ensure node is in PATH (just installed by home-manager)
    export PATH="$HOME/.nix-profile/bin:$PATH"
    VERCEL_USER=$("$HOME/.bun/bin/vercel" whoami --token="$VERCEL_TOKEN_VAL" 2>/dev/null)
    if [[ -n "$VERCEL_USER" ]]; then
      echo "Vercel CLI authenticated as: $VERCEL_USER"
    else
      echo "WARNING: Vercel token found but authentication failed. Check VERCEL_TOKEN in 1Password."
    fi
  fi
fi

# -----------------------------------------------------------------------------
# [9/10] Clone project repos
# -----------------------------------------------------------------------------
echo ""
echo "[9/10] Cloning project repos..."
mkdir -p "$HOME/code/tilt"

for repo in TILT-Legal/Mobius TILT-Legal/Cubitt; do
  repo_name="${repo##*/}"
  if [[ ! -d "$HOME/code/tilt/$repo_name" ]]; then
    git clone "git@github.com:$repo.git" "$HOME/code/tilt/$repo_name"
    echo "Cloned $repo_name."
  else
    echo "$repo_name already cloned."
  fi
done

# Enable lingering so systemd user services run without an active login session
loginctl enable-linger "$USER"

# Start OpenCode server
systemctl --user start opencode 2>/dev/null || true

# -----------------------------------------------------------------------------
# [10/10] Authenticate GitHub CLI (interactive — device code flow)
# -----------------------------------------------------------------------------
# This is last because it requires manual interaction (entering a code at
# github.com/login/device). Only needed for gh API operations (PRs, issues,
# etc.) — all git clone/push/pull uses SSH above.
echo ""
echo "[10/10] Authenticating GitHub CLI..."

# Use gh via nix run (avoids nix profile conflict with home-manager)
GH_CMD="nix run nixpkgs#gh --"

if ! $GH_CMD auth status &>/dev/null 2>&1; then
  echo "Starting device code flow (org policies require OAuth, not PATs)..."
  echo "You'll need to visit a URL and enter a code on another device."
  echo ""
  $GH_CMD auth login --git-protocol https --web
  echo "GitHub CLI authenticated."
else
  echo "GitHub CLI already authenticated."
fi

# Configure git to use gh for HTTPS auth (fallback for any HTTPS remotes)
$GH_CMD auth setup-git

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
