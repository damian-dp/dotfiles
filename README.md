# Damian's Dotfiles

Reproducible development environment using Nix flakes, home-manager, and nix-darwin.

## Overview

Two configurations:

| Config | Platform | Use Case | Command |
|--------|----------|----------|---------|
| `damian@linux` | Linux x86_64 | VMs, servers (headless) | `home-manager switch --flake .#damian@linux` |
| `Damian-MBP` | macOS ARM | Workstation (full setup) | `darwin-rebuild switch --flake .#Damian-MBP` |

## Quick Start

### New Linux VM (OpenCode Dev Server)

The bootstrap script sets up a fresh VM as a remote dev environment with OpenCode web, Tailscale, and all your tools. It uses a 1Password Service Account to pull all secrets automatically.

**One-time setup (from your Mac):**

1. Create a **VM** vault in 1Password
2. Add these items to the VM vault:
   - `TS_AUTH_KEY` — Tailscale auth key (field: `credential`)
   - `GH_SSH_KEY` — your ed25519 SSH key (SSH key item)
   - `GH_MASTER_PAT` — GitHub PAT with repo scope (field: `token`)
3. Create a **Service Account** (1Password Settings > Developer > Service Accounts)
   - Grant `read_items` access to the VM vault only
   - Save the token (starts with `ops_`)

**On the fresh VM:**

```bash
git clone https://github.com/damian-dp/dotfiles.git ~/dotfiles
cd ~/dotfiles
OP_SERVICE_ACCOUNT_TOKEN='ops_...' ./bootstrap-vm.sh
```

The script will pause after installing Nix to restart your shell. Run it again to continue:

```bash
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
OP_SERVICE_ACCOUNT_TOKEN='ops_...' ./bootstrap-vm.sh
```

After completion, access OpenCode from any Tailscale device:
- **Browser (phone/laptop):** `http://<tailscale-hostname>:4096`
- **Terminal:** `opencode attach http://<tailscale-hostname>:4096`

### New macOS Workstation

```bash
git clone https://github.com/damian-dp/dotfiles.git ~/dotfiles
cd ~/dotfiles
nix run nix-darwin -- switch --flake .#Damian-MBP
```

### Updating

```bash
cd ~/dotfiles
git pull

# Linux
home-manager switch --flake .#damian@linux

# macOS
darwin-rebuild switch --flake .#Damian-MBP
```

## Repository Structure

```
dotfiles/
├── flake.nix                 # Main entry - defines configurations
├── flake.lock                # Pinned dependencies
├── bootstrap-vm.sh           # VM bootstrap (1Password + Tailscale + OpenCode)
│
├── home/
│   ├── core.nix              # Shared: CLI tools, dotfiles
│   ├── linux.nix             # Linux-specific config
│   ├── workstation.nix       # macOS: fonts, app configs (Ghostty/Zed/Cursor)
│   ├── modules/
│   │   └── opencode.nix      # OpenCode systemd service module
│   └── dotfiles/
│       ├── zshrc             # Shell config
│       ├── p10k.zsh          # Powerlevel10k theme
│       ├── gitconfig-macos   # macOS 1Password signing path
│       ├── gitconfig-linux   # Linux local key signing path
│       ├── ssh_config        # SSH config
│       ├── ghostty.conf      # Terminal config
│       ├── tmux.conf         # Tmux config
│       ├── shell/
│       │   └── commit.sh     # Claude-powered commit messages
│       ├── opencode/         # OpenCode config files
│       └── claude/           # Claude CLI config
│
├── darwin/
│   └── system.nix            # macOS system preferences
│
├── nixos/
│   └── configuration.nix     # NixOS system config (if needed)
│
└── configs/                  # Workstation app configs (macOS)
    └── cursor/
        ├── settings.json
        └── keybindings.json
```

## What's Included

### Both Platforms (core.nix)

- **Shell**: zsh + oh-my-zsh + Powerlevel10k
- **Tools**: git, gh, ripgrep, fd, fzf, eza, zoxide, delta, lazygit, jq, htop, btop, tmux, direnv
- **Python**: uv (fast Python package manager)
- **Network**: tailscale, mosh (low-latency SSH)
- **AI**: Claude Code, OpenCode (installed outside Nix for auto-updates)
- **Git**: SSH commit signing via 1Password

### macOS Workstation (workstation.nix + darwin/system.nix)

- **Fonts**: Nerd Fonts (Meslo, JetBrains Mono)
- **App configs**: Ghostty, Zed, Cursor
- **System prefs**: Dock autohide, dark mode, text replacements
- **Services**: Tailscale, Touch ID for sudo

### Linux VM (linux.nix + opencode.nix)

- **OpenCode**: systemd service running `opencode web` on port 4096
- **Docker**: docker + docker-compose
- **Access**: via Tailscale (no public ports)

## Config Management

| Method | Description | Use Case |
|--------|-------------|----------|
| **Nix module** | Declarative config in `.nix` files | Apps with home-manager modules (git, gh, zed) |
| **Symlink** | Read-only link to nix store | Configs that don't change (keybindings, themes) |
| **Copy-once** | Copied on first run, then writable | Apps that write state/permissions to config |

## Git Commit Signing

All commits are automatically signed using SSH keys stored in 1Password. No special commands needed — `git commit` just works.

### macOS

Uses 1Password desktop app's built-in `op-ssh-sign` binary. Requires:
- 1Password desktop app installed
- SSH agent enabled in 1Password settings
- SSH key added to 1Password

### Linux (Headless VM)

Uses a local SSH key at `~/.ssh/id_ed25519_signing`, extracted from 1Password during bootstrap. The 1Password SSH agent and `op-ssh-sign` require the desktop GUI app, so headless VMs use a local key file instead.

The `gitconfig-linux` include points `user.signingkey` at the local `.pub` file.

### GitHub Setup

For commits to show as "Verified" on GitHub:

1. Go to [GitHub SSH Keys](https://github.com/settings/keys)
2. Click **New SSH key**
3. Set **Key type: Signing Key** (not Authentication)
4. Paste your public key
5. Ensure your commit email matches a verified email on your GitHub account

## Shell Aliases

| Alias | Command |
|-------|---------|
| `ll` | `ls -la` |
| `gs` | `git status` |
| `gp` | `git push` |
| `gl` | `git pull` |
| `lg` | `lazygit` |
| `ta` | `tmux attach -t` |
| `tl` | `tmux ls` |
| `tn` | `tmux new -s` |
| `signin` | Sign in to 1Password CLI (personal + work accounts) |

## Text Replacements (macOS)

| Type | Expands To |
|------|------------|
| `@@` | hello@damianpetrov.com |
| `@&` | damian.petrov@tilt.legal |
| `omw` | On my way! |

## Updating Nix Packages

```bash
cd ~/dotfiles
nix flake update
darwin-rebuild switch --flake .#Damian-MBP  # or home-manager for Linux
```

## Adding Packages

Edit the appropriate file:

- **All platforms**: `home/core.nix` → `home.packages`
- **macOS only**: `home/workstation.nix` → `home.packages`
- **macOS system**: `darwin/system.nix` → `environment.systemPackages`

## License

Personal configuration - feel free to fork and adapt.
