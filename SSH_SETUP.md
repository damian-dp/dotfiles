# SSH Setup with 1Password

This guide covers SSH configuration for both macOS (with 1Password desktop app) and Linux VMs (CLI-only).

## Table of Contents

- [Overview](#overview)
- [macOS Setup (Workstation)](#macos-setup-workstation)
- [Linux Setup (Headless VMs)](#linux-setup-headless-vms)
- [SSH Bookmarks (Solving the 6-Key Limit)](#ssh-bookmarks-solving-the-6-key-limit)
- [Troubleshooting](#troubleshooting)
- [Official 1Password Documentation](#official-1password-documentation)

## Overview

We use 1Password to manage SSH keys across all machines. The setup differs between platforms:

| Platform | 1Password App | SSH Agent | Key Storage |
|----------|---------------|-----------|-------------|
| macOS | Desktop GUI | 1Password SSH Agent | Keys in 1Password vault |
| Linux VM | CLI only | System SSH agent | Local key files extracted from 1Password |

## macOS Setup (Workstation)

On macOS, the 1Password desktop app provides a built-in SSH agent that manages all your keys.

### Prerequisites

1. Install [1Password for Mac](https://1password.com/downloads/mac)
2. Enable the SSH Agent in 1Password:
   - Open 1Password → **Settings** → **Developer**
   - Enable **"Use the SSH agent"**

> **Official guide**: [Get started with 1Password SSH](https://developer.1password.com/docs/ssh/get-started)

### SSH Config (macOS)

Add the following to `~/.ssh/config` to use the 1Password SSH agent:

```ssh-config
# 1Password SSH Agent (macOS)
Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
```

### Verify Setup

```bash
# Check if 1Password agent is responding
ssh-add -l

# You should see your keys listed, e.g.:
# 256 SHA256:YgTCV5... my-ssh-key (ED25519)
# 256 SHA256:aFh6yx... Github (ED25519)
```

## Linux Setup (Headless VMs)

Linux VMs without a desktop environment can't use the 1Password SSH agent. Instead, we extract keys from 1Password and store them locally.

### Prerequisites

1. Install 1Password CLI:
   ```bash
   # Add 1Password apt repository
   curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
     sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
   
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
     sudo tee /etc/apt/sources.list.d/1password.list
   
   sudo apt update && sudo apt install 1password-cli
   ```

2. Sign in to 1Password:
   ```bash
   op account add --address my.1password.com --email your@email.com
   eval $(op signin)
   ```

### SSH Config (Linux)

The dotfiles provide a basic SSH config. Add your VMs after setting them up:

```ssh-config
# Development VMs (Tailscale)
Host dev-vm
    HostName <tailscale-ip>
    User damian

# Global Settings
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    AddKeysToAgent yes
```

### Extract SSH Keys from 1Password (Linux)

For Git commit signing or SSH authentication on headless VMs:

```bash
# Sign in first
eval $(op signin)

# Extract private key
op item get "Your SSH Key Name" --vault "Your Vault" --fields "private key" --reveal > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519

# Extract public key
op item get "Your SSH Key Name" --vault "Your Vault" --fields "public key" > ~/.ssh/id_ed25519.pub
chmod 644 ~/.ssh/id_ed25519.pub
```

## SSH Bookmarks (Solving the 6-Key Limit)

### The Problem

OpenSSH servers limit authentication attempts to 6 by default (`MaxAuthTries`). If you have more than 6 SSH keys in your agent, connections will fail with:

```
Received disconnect from X.X.X.X port 22:2: Too many authentication failures
```

### The Solution: 1Password SSH Bookmarks

SSH Bookmarks tell 1Password which key to use for each host, avoiding the 6-key limit.

> **Official guide**: [SSH Bookmarks](https://developer.1password.com/docs/ssh/bookmarks)

### Step 1: Enable SSH Config Generation

1. Open 1Password → **Settings** → **Developer**
2. Expand **SSH Agent** → **Advanced**
3. Enable **"Generate SSH config files from 1Password SSH bookmarks"**

This creates `~/.ssh/1Password/config` with automatic key mappings.

### Step 2: Add Bookmarks to SSH Keys

For each SSH key item in 1Password:

1. Open the SSH Key item
2. Click **Edit**
3. Add a new **URL field** with format: `ssh://user@hostname`

Example bookmarks:

| SSH Key Item | Bookmark URLs |
|--------------|---------------|
| `Azure Dev VM` | `ssh://damian@dev-vm`<br>`ssh://damian@100.x.x.x` |
| `GitHub` | `ssh://git@github.com` |

### Step 3: Include 1Password Config

Add this line near the top of `~/.ssh/config`:

```ssh-config
# 1Password SSH Bookmarks - auto-managed key mapping
Include ~/.ssh/1Password/config
```

### Generated Config Example

1Password will generate `~/.ssh/1Password/config` like this:

```ssh-config
# This config file is automatically generated and managed by 1Password.
# Any manual edits will be lost.

# 1Password Item: Azure Dev VM
Match Host dev-vm User damian
  IdentitiesOnly yes
  IdentityFile ~/.ssh/1Password/SHA256_xxxxx.pub

Match all
```

### Complete macOS SSH Config Example

Here's a complete `~/.ssh/config` for macOS with 1Password:

```ssh-config
# OrbStack (if installed)
Include ~/.orbstack/ssh/config

# 1Password SSH Bookmarks - auto-managed key mapping
Include ~/.ssh/1Password/config

# 1Password SSH Agent
Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# Global Settings
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    AddKeysToAgent yes
```

## Troubleshooting

### "Too many authentication failures"

**Cause**: More than 6 keys in SSH agent, server rejects before correct key is tried.

**Fix**: Set up [SSH Bookmarks](#ssh-bookmarks-solving-the-6-key-limit) to map keys to hosts.

**Quick workaround** (temporary):
```bash
# Force specific key for one connection
ssh -o IdentitiesOnly=yes -i ~/.ssh/specific_key.pub user@host
```

### "User not allowed because shell does not exist"

**Cause**: On Linux VMs with nix home-manager, the shell is set to `~/.nix-profile/bin/zsh` but nix paths aren't in the environment when SSH starts.

**Fix**: This is now handled automatically by our dotfiles. The `programs.zsh.envExtra` sources nix-daemon.sh to set up PATH before the shell starts. If you hit this issue:

```bash
# Temporary fix via Azure CLI or console
sudo chsh -s /bin/bash username

# Then run home-manager switch to apply the fixed config
cd ~/dotfiles && git pull
nix run home-manager -- switch --flake .#damian@linux
```

### 1Password SSH agent not responding

**macOS**:
```bash
# Check if agent socket exists
ls -la ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock

# Verify 1Password is running and SSH agent is enabled
# Settings → Developer → Use the SSH agent
```

**Linux**: The 1Password SSH agent requires the desktop app. On headless VMs, use local key files instead.

### Keys not showing in `ssh-add -l`

1. Ensure 1Password is unlocked
2. Check SSH agent is enabled in 1Password settings
3. Verify keys are in **Personal** or **Private** vault (not shared vaults by default)

To use keys from other vaults, create an [agent config file](https://developer.1password.com/docs/ssh/agent/config):

```toml
# ~/.config/1Password/ssh/agent.toml
[[ssh-keys]]
vault = "Work"
```

## Official 1Password Documentation

- [1Password SSH & Git Overview](https://developer.1password.com/docs/ssh)
- [Get Started with SSH](https://developer.1password.com/docs/ssh/get-started)
- [SSH Agent](https://developer.1password.com/docs/ssh/agent)
- [SSH Bookmarks](https://developer.1password.com/docs/ssh/bookmarks)
- [Advanced Use Cases](https://developer.1password.com/docs/ssh/agent/advanced) (6-key limit, multiple identities)
- [Agent Config File](https://developer.1password.com/docs/ssh/agent/config)
- [Git Commit Signing](https://developer.1password.com/docs/ssh/git-commit-signing)
