# Damian's Dotfiles

Reproducible development environment using Nix flakes, home-manager, and nix-darwin.

## Overview

Four configurations:

| Config | Platform | Use Case | Command |
|--------|----------|----------|---------|
| `damian@linux` | Linux x86_64 | VMs, servers (headless + OpenCode) | `home-manager switch --flake .#damian@linux` |
| `damian@linux-client` | Linux x86_64 | Linux desktop (no OpenCode server) | `home-manager switch --flake .#damian@linux-client` |
| `Damian-MBP` | macOS ARM | MacBook Pro (shared macOS profile) | `darwin-rebuild switch --flake .#Damian-MBP` |
| `Damian-Studio` | macOS ARM | Mac Studio (shared macOS profile) | `darwin-rebuild switch --flake .#Damian-Studio` |

## Quick Start

### New Linux VM (OpenCode Dev Server)

The bootstrap script sets up a fresh VM as a remote dev environment with OpenCode web, Tailscale, and all your tools. It uses a 1Password Service Account to pull all secrets automatically.

**One-time setup (from your Mac):**

1. Create a **VM** vault in 1Password
2. Add these items to the VM vault:
   - `TS_AUTH_KEY` — Tailscale auth key (field: `credential`)
   - `GH_SSH_KEY` — your ed25519 SSH key (SSH key item)
   - `VERCEL_TOKEN` — Vercel auth token (field: `token`, optional — only needed for Vercel deploys)
   - `GH_CLASSIC_PAT` — GitHub classic PAT (field: `token`, optional — only needed for private npm packages)
   - `VERCEL_BYPASS_SECRET` — Vercel bypass secret (field: `credential`, optional — only needed for canary MCP auth)
3. Create a **Service Account** (1Password Settings > Developer > Service Accounts)
   - Grant `read_items` access to the VM vault only
   - Save the token (starts with `ops_`)

**On the fresh VM:**

```bash
sudo apt update && sudo apt upgrade -y && sudo reboot
# SSH back in after reboot

git clone https://github.com/damian-dp/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles
OP_SERVICE_ACCOUNT_TOKEN='ops_...' ./bootstrap-vm.sh
```

The script will pause after installing Nix to restart your shell. Run it again to continue:

```bash
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
OP_SERVICE_ACCOUNT_TOKEN='ops_...' ./bootstrap-vm.sh
```

The service account token is saved to `~/.config/op/service-account-token` on first run. You won't need to provide it again — subsequent runs of the bootstrap script and all shell sessions automatically load it.

After completion, access OpenCode from any Tailscale device:
- **Browser (phone/laptop):** `http://<tailscale-hostname>:4096`
- **Terminal:** `opencode attach http://<tailscale-hostname>:4096`

### New macOS Workstation

```bash
# Install Nix first (for example with the official installer or Lix),
# then clone the repo and apply the host config.
git clone https://github.com/damian-dp/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles
sudo nix run github:nix-darwin/nix-darwin/master#darwin-rebuild -- switch --flake .#Damian-MBP

# Or for the always-on desktop:
sudo nix run github:nix-darwin/nix-darwin/master#darwin-rebuild -- switch --flake .#Damian-Studio

# Install external AI CLIs explicitly
./scripts/setup-ai-clis.sh

# Verify the machine state
./scripts/verify-machine.sh mac
```

If you want App Store apps (`Microsoft Outlook`, `Microsoft Teams`) to install on the first pass, sign into the App Store before running `darwin-rebuild`. Otherwise, sign in and run `darwin-rebuild switch` again.

### Updating

```bash
cd ~/code/dotfiles
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
├── bootstrap-vm.sh           # VM bootstrap (1Password + Tailscale + OpenCode + firewall)
├── secrets/
│   ├── README.md             # Secret reference registry docs
│   └── refs/
│       ├── common.env        # Shared 1Password secret references
│       ├── mac.env           # macOS-only secret references
│       └── vm.env            # Headless VM secret references
│
├── home/
│   ├── core.nix              # Shared: CLI tools, dotfiles, writable config deployment
│   ├── linux.nix             # Linux-specific config
│   ├── workstation.nix       # Shared macOS user config (fonts, app configs, editor settings)
│   ├── modules/
│   │   └── opencode.nix      # OpenCode systemd service module
│   └── dotfiles/
│       ├── zshrc             # Shell config (1Password agent, PATH, aliases, functions)
│       ├── p10k.zsh          # Powerlevel10k theme
│       ├── gitconfig-macos   # macOS 1Password signing path
│       ├── gitconfig-linux   # Linux key signing path + global git hooks
│       ├── ssh_config        # SSH config
│       ├── ghostty.conf      # Terminal config
│       ├── tmux.conf         # Tmux config
│       ├── shell/
│       │   ├── commit.sh         # Claude-powered commit messages
│       │   ├── pnpm-wrapper.sh   # Injects GH_NPM_TOKEN on Linux VMs
│       │   ├── vercel-wrapper.sh # Injects Vercel token on Linux VMs
│       │   └── git-hooks/        # Global git hooks (Linux VMs only)
│       │       ├── pre-commit    # Blocks commits to main/master
│       │       └── pre-push      # Blocks pushes to main/master
│       ├── claude/           # Claude Code config (CLAUDE.md + settings.json)
│       ├── codex/            # Codex CLI config (AGENTS.md + config.toml)
│       ├── opencode/         # OpenCode config files
│       └── warp/             # Warp launch configurations
│
├── darwin/
│   ├── common.nix            # Shared macOS system config + Homebrew/App Store apps
│   └── hosts/
│       ├── mbp.nix           # MacBook Pro host identity
│       └── studio.nix        # Mac Studio host identity
│
├── scripts/
│   ├── setup-ai-clis.sh      # Explicit installer/configurer for external AI CLIs
│   ├── with-secrets.sh       # Run commands with secret refs resolved by 1Password
│   ├── render-secret-configs.sh # Render runtime configs from secret-backed templates
│   └── verify-machine.sh     # Cross-platform post-setup verification checks
│
├── nixos/
│   └── configuration.nix     # NixOS system config (if running NixOS)
│
├── configs/                  # Workstation app configs (macOS)
│   └── cursor/
│       ├── settings.json
│       └── keybindings.json
│
└── SSH_SETUP.md              # Detailed SSH + 1Password setup guide
```

## What's Included

### Both Platforms (core.nix)

- **Shell**: zsh + oh-my-zsh + Powerlevel10k
- **Tools**: git, gh, curl, wget, ripgrep, fd, fzf, eza, zoxide, delta, lazygit, jq, tree, htop, btop, tmux, direnv, caddy
- **Python**: uv (fast Python package manager)
- **JS**: Node.js, pnpm
- **LSP**: typescript-language-server, biome (used by AI coding tools)
- **Network**: tailscale
- **AI**: Claude Code, OpenCode, Codex, Bun global tools (installed via `scripts/setup-ai-clis.sh`)
- **Git**: SSH commit signing via 1Password

### macOS Workstation (workstation.nix + darwin/common.nix + darwin/hosts/*)

- **Fonts**: Nerd Fonts (Meslo, JetBrains Mono)
- **Tools**: bat, 1Password CLI, PostgreSQL 17 client tools
- **App configs**: Ghostty, Zed, Cursor, Warp (launch configs)
- **Apps**: managed declaratively via Homebrew casks + App Store apps
- **System prefs**: auto light/dark mode, Finder show extensions/path bar, text replacements
- **Services**: Tailscale, Touch ID for sudo

### Linux VM (linux.nix + opencode.nix)

- **OpenCode**: systemd service running `opencode web` on port 4096
- **Docker**: docker + docker-compose
- **Caddy**: copied with `cap_net_bind_service` for port 80 binding
- **CLI wrappers**: `pnpm` and `vercel` wrappers that inject 1Password tokens
- **Git hooks**: global hooks prevent commits and pushes to `main`/`master` branches
- **Access**: OpenCode restricted to `tailscale0` by host firewall rules

## AI Coding Tools

Three AI coding CLIs are installed outside Nix (for auto-updates) with configs managed by dotfiles. Use `./scripts/setup-ai-clis.sh` after a rebuild or on a fresh machine. It also renders the secret-backed Codex/OpenCode runtime configs.

### Permissions

All tools are configured for maximum autonomy by default:

| Tool | Setting | Config File |
|------|---------|-------------|
| **Claude Code** | `"defaultMode": "bypassPermissions"` | `claude/settings.json` |
| **Codex** | `approval_policy = "never"` + `sandbox_mode = "danger-full-access"` | `codex/config.toml` |
| **OpenCode** | `"permission": "allow"` | `opencode/opencode.json` |

### Global Instructions

| Tool | File | Deployed To |
|------|------|-------------|
| **Claude Code** | `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` (symlink, read-only) |
| **Codex** | `codex/AGENTS.md` | `~/.codex/AGENTS.md` (symlink, read-only) |

### MCP Servers

Each tool has its own MCP config format. The shared servers are:

| Server | Description |
|--------|-------------|
| **deepwiki** | AI-powered GitHub repo documentation |
| **cubitt** | Cubitt design system docs |
| **cubitt-canary** | Cubitt canary environment (with Vercel bypass auth) |

Codex also has: figma, context7, playwright.

The Vercel bypass secret is no longer fetched during rebuilds. Secret references now live in `secrets/refs/*.env`, and live Codex/OpenCode configs are rendered explicitly by `./scripts/render-secret-configs.sh`. Sync-back intentionally excludes those live files to avoid committing rendered secrets.

## Shell Functions

### `vm` — SSH to Linux VM

```bash
vm                              # plain SSH
vm --tunnel 3000                # forward port 3000
vm -t 3000 -t 5173             # forward multiple ports
```

Prints tunneled ports before connecting. The SSH host `vm` resolves via Tailscale.

### `opencode` — Smart OpenCode Wrapper

```bash
opencode              # auto-detect: VM if reachable, else local
opencode local        # force local
opencode vm           # force VM
opencode --cubitt     # attach to VM in ~/code/tilt/cubitt
opencode --mobius     # attach to VM in ~/code/tilt/mobius
opencode --dotfiles   # attach to VM in ~/code/dotfiles
```

When connecting to the VM from a local project directory (`~/code/tilt/cubitt`, etc.), the matching VM directory is passed via `--dir` automatically.

Connection mode is logged to `~/.local/state/opencode.log`.

### `dotfiles-sync` — Sync Live Configs Back to Repo

Copies modified writable configs that are safe to sync back into the dotfiles repo for review and commit.

```bash
dotfiles-sync
cd ~/code/dotfiles && git diff
```

Currently this syncs `Claude` settings only. Live `Codex` and `OpenCode` configs are excluded because they are rendered from secret-backed templates.

## Config Management

| Method | Description | Use Case |
|--------|-------------|----------|
| **Nix module** | Declarative config in `.nix` files | Apps with home-manager modules (git, zed) |
| **Symlink** | Read-only link to nix store | Configs that don't change (CLAUDE.md, AGENTS.md, keybindings) |
| **Overwrite on rebuild** | Copied from dotfiles every rebuild | Non-secret writable configs (Claude settings, Cursor settings) |
| **Explicit render** | Rendered from templates with 1Password secret refs | Secret-backed runtime configs (Codex, OpenCode) |

## 1Password Secrets (VM)

The VM uses a 1Password **Service Account** scoped to the VM vault only (no access to personal or other vaults). The bootstrap script pulls secrets once and persists them locally:

| Secret | 1Password Item | How It's Used |
|--------|---------------|---------------|
| Service account token | (provided manually once) | Saved to `~/.config/op/service-account-token`, auto-loaded in every shell |
| Tailscale auth key | `TS_AUTH_KEY` | Used once during bootstrap (not persisted) |
| SSH signing key | `GH_SSH_KEY` | Extracted to `~/.ssh/id_ed25519_signing` (needed on disk for git/ssh) |
| GitHub OAuth | (device code flow) | `gh auth login --web` during bootstrap for `gh` API usage, stored in `~/.config/gh/hosts.yml` |
| GitHub classic PAT | `GH_CLASSIC_PAT` | Exposed to Linux `pnpm` through `scripts/with-secrets.sh` |
| Vercel token | `VERCEL_TOKEN` | Exposed to Linux `vercel` through `scripts/with-secrets.sh` |
| Vercel bypass secret | `VERCEL_BYPASS_SECRET` | Rendered into Codex/OpenCode configs by `scripts/render-secret-configs.sh` |

The service account token is the only secret saved to disk by the bootstrap. It's auto-loaded in every shell session, enabling `scripts/with-secrets.sh` to resolve the central secret reference files on demand.

## Secret Workflow

The source of truth for secret wiring is in `secrets/refs/`. Add new `op://...` references there, then consume them through:

- `./scripts/with-secrets.sh` for one-off commands or wrappers
- `./scripts/render-secret-configs.sh` for runtime config files

This keeps secrets out of Nix activation and out of git-tracked runtime files.

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

Global git hooks (`~/.config/git-hooks/`) prevent direct commits and pushes to `main`/`master` branches on VMs. Create a feature branch and PR instead.

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
| `vibe-claude` | `claude --dangerously-skip-permissions` |
| `vibe-codex` | `codex --full-auto` |
| `signin` | Sign in to 1Password CLI (personal + work accounts) |

## Text Replacements (macOS)

| Type | Expands To |
|------|------------|
| `@@` | hello@damianpetrov.com |
| `@&` | damian.petrov@tilt.legal |
| `omw` | On my way! |

## Updating Nix Packages

```bash
cd ~/code/dotfiles
nix flake update
darwin-rebuild switch --flake .#Damian-MBP  # or home-manager for Linux
```

## Verification

Run the machine verification script after a rebuild or bootstrap:

```bash
./scripts/verify-machine.sh
./scripts/verify-machine.sh mac
./scripts/verify-machine.sh vm
./scripts/verify-machine.sh linux-client
```

## Adding Packages

Edit the appropriate file:

- **All platforms**: `home/core.nix` → `home.packages`
- **macOS only**: `home/workstation.nix` → `home.packages`
- **macOS system + apps**: `darwin/common.nix`

## License

Personal configuration - feel free to fork and adapt.
