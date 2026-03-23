# macOS App Inventory

Canonical GUI app inventory for both Macs. These apps are managed declaratively via nix-darwin Homebrew/App Store config, not installed manually one by one.

## Essential

| App | Source | Notes |
|-----|--------|-------|
| [1Password](https://1password.com/downloads/mac/) | Homebrew Cask | Password manager, SSH agent |
| [Ghostty](https://ghostty.org/) | Homebrew Cask | Terminal emulator |
| [Tailscale](https://tailscale.com/download) | Homebrew Cask | VPN mesh network |

## Development

| App | Source | Notes |
|-----|--------|-------|
| [Zed](https://zed.dev/) | Homebrew Cask | Primary editor |
| [Cursor](https://cursor.sh/) | Homebrew Cask | AI-assisted editor |
| [OrbStack](https://orbstack.dev/) | Homebrew Cask | Docker & Linux VMs |
| [GitKraken](https://www.gitkraken.com/) | Homebrew Cask | Git GUI (optional) |

## Browsers

| App | Source | Notes |
|-----|--------|-------|
| [Arc](https://arc.net/) | Homebrew Cask | Primary browser |
| [Chrome](https://www.google.com/chrome/) | Homebrew Cask | Testing/compatibility |

## Productivity

| App | Source | Notes |
|-----|--------|-------|
| [Raycast](https://www.raycast.com/) | Homebrew Cask | Spotlight replacement |
| Microsoft Outlook | App Store (`mas`) | Email |
| Microsoft Teams | App Store (`mas`) | Communication |

## Utilities

| App | Source | Notes |
|-----|--------|-------|
| [LM Studio](https://lmstudio.ai/) | Homebrew Cask | Local LLMs |

## CLI / Runtime Tools

These are not part of the GUI inventory:

- Core CLI tools, `1password-cli`, and PostgreSQL 17 are managed in Nix.
- External AI CLIs (`Claude Code`, `OpenCode`, `Codex`, Bun global tools) are installed via `./scripts/setup-ai-clis.sh`.

## Post-Install Setup

### 1Password SSH Agent

After the 1Password app is installed, enable the SSH agent:
1. Open 1Password → Settings → Developer
2. Enable "Use the SSH Agent"
3. The agent socket is at `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`

### Ghostty

Config is managed by home-manager (symlinked from `home/dotfiles/ghostty.conf`).

Target: `~/Library/Application Support/com.mitchellh.ghostty/config`

### Zed

Config is managed declaratively via `programs.zed-editor` in `home/workstation.nix`.
Edit the Nix file, then rebuild to apply changes.

### Cursor

Config is copied from `configs/cursor/settings.json` into `~/Library/Application Support/Cursor/User/settings.json` during rebuilds.

### App Store apps

Microsoft Outlook and Microsoft Teams are managed through `mas`.
On a fresh Mac, sign into the App Store first so `darwin-rebuild` can install them.
