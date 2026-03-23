# macOS App Inventory

Canonical GUI app inventory for both Macs.

Preferred source strategy:

- Use Homebrew casks for mainstream macOS GUI apps.
- Use App Store (`mas`) only for apps that are App Store-only or cleaner there.
- Use Nix for CLI/runtime tools, not for most proprietary macOS GUI apps.

## Essential

| App | Source | Notes |
|-----|--------|-------|
| [1Password](https://1password.com/downloads/mac/) | Homebrew Cask | Password manager, SSH agent |
| 1Password for Safari | App Store (`mas`) | Safari extension companion |
| [Ghostty](https://ghostty.org/) | Homebrew Cask | Terminal emulator |
| [Tailscale](https://tailscale.com/download) | Homebrew Cask | VPN mesh network |

## Development

| App | Source | Notes |
|-----|--------|-------|
| [Zed](https://zed.dev/) | Homebrew Cask | Primary editor |
| [Cursor](https://cursor.sh/) | Homebrew Cask | AI-assisted editor |
| [OrbStack](https://orbstack.dev/) | Homebrew Cask | Provides the macOS Docker-compatible runtime and CLI |
| [Warp](https://www.warp.dev/) | Homebrew Cask | Alternate terminal |
| [T3 Code](https://t3.codes/) | Homebrew Cask | Minimal GUI for AI code agents |
| [Figma](https://www.figma.com/) | Homebrew Cask | Design collaboration |
| [Linear](https://linear.app/) | Homebrew Cask | Issue tracking |
| [Logi Tune](https://www.logitech.com/en-us/video-collaboration/software/logi-tune-software.html) | Homebrew Cask | Logitech device management |
| [Nucleo](https://nucleoapp.com/) | Homebrew Cask | Icon manager |

## Browsers

| App | Source | Notes |
|-----|--------|-------|
| [Chrome](https://www.google.com/chrome/) | Homebrew Cask | Testing/compatibility |
| Safari | macOS built-in | Not managed separately |

## AI / Communication

| App | Source | Notes |
|-----|--------|-------|
| [ChatGPT](https://chatgpt.com/) | Homebrew Cask | OpenAI desktop app |
| [Claude](https://claude.com/download) | Homebrew Cask | Anthropic desktop app |
| [Codex](https://openai.com/codex) | Homebrew Cask | OpenAI desktop app |
| Codex (Beta) | Manual | No clean official Homebrew/App Store package found |
| [CodexBar](https://codexbar.app/) | Homebrew Cask | Menu bar monitor |
| [Discord](https://discord.com/) | Homebrew Cask | Communication |

## Productivity

| App | Source | Notes |
|-----|--------|-------|
| [Raycast](https://www.raycast.com/) | Homebrew Cask | Spotlight replacement |
| Microsoft Outlook | Homebrew Cask | Email |
| Microsoft Teams | Homebrew Cask | Communication |
| Microsoft Excel | Homebrew Cask | Spreadsheet |
| Microsoft Word | Homebrew Cask | Documents |
| OneDrive | Homebrew Cask | Cloud storage |
| [Notion](https://www.notion.com/) | Homebrew Cask | Notes and docs |
| [Setapp](https://setapp.com/) | Homebrew Cask | Subscription app launcher |
| [Spotify](https://www.spotify.com/) | Homebrew Cask | Music |
| Caffeinated | App Store (`mas`) | Keep Mac awake |
| BetterJSON | App Store (`mas`) | JSON viewer/editor |
| WhatFont | App Store (`mas`) | Font inspection tool |

## Setapp-Managed Apps

These apps matter to the machine setup, but they should be installed through Setapp itself rather than standalone casks so licensing and entitlement stay on the Setapp path.

| App | Source | Notes |
|-----|--------|-------|
| [OpenIn](https://setapp.com/apps/openin) | Manual via Setapp | Required default-browser/link-routing workflow |
| [Typeface](https://setapp.com/apps/typeface) | Manual via Setapp | Required font management workflow |

## Design / Utilities

| App | Source | Notes |
|-----|--------|-------|
| [Affinity Designer 2](https://affinity.serif.com/en-us/designer/) | Homebrew Cask | Vector design |
| [Affinity Photo 2](https://affinity.serif.com/en-us/photo/) | Homebrew Cask | Photo editing |
| [Affinity Publisher 2](https://affinity.serif.com/en-us/publisher/) | Homebrew Cask | Publishing |
| [Bambu Studio](https://bambulab.com/en/download/studio) | Homebrew Cask | 3D printing |
| [BetterDisplay](https://betterdisplay.pro/) | Homebrew Cask | Display management |

## CLI / Runtime Tools

These are not part of the GUI inventory:

- On macOS, `1password-cli` is managed via Homebrew cask.
- On Linux VMs, `1password-cli` is installed by `bootstrap-vm.sh` from 1Password's apt repository.
- PostgreSQL 17, Node.js, pnpm, and Bun are managed in Nix.
- `Bun` is installed as a runtime for repos that use it, but not used for machine-level global installs.
- On macOS, `docker`/`docker compose` come from OrbStack rather than a separate Docker Desktop install.
- On Linux VMs, `docker` and Compose come from Nix packages.
- External AI CLIs with their own installers (`Claude Code`, `OpenCode`) are installed via `./scripts/setup-ai-clis.sh`.
- Shared global JS CLIs (`Codex`, `turbo`, `vercel`, `tailwindcss`, `portless`) are installed via `./scripts/setup-js-globals.sh`.
- The intended machine contract is: Homebrew/App Store for GUI apps, Nix for runtimes/system tools, pnpm for global JS CLIs, no npm globals, no Bun globals.

## Inventory Notes

- `/Applications` is the app bundle destination. Apps installed via Homebrew casks also appear there, so seeing an app in both `/Applications` and `brew list --cask` is normal and not a duplicate install.
- `/Applications/Nix Apps` and `~/Applications/Home Manager Apps` are generated alias folders for GUI apps installed from the Nix store. They are not where you manually put apps.
- This repo intentionally uses Homebrew casks for most GUI apps because that is the cleaner macOS path for proprietary apps; pure Nix is kept for CLI tools and declarative system/user config.

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

1Password for Safari, Caffeinated, BetterJSON, and WhatFont are managed through `mas`.
On a fresh Mac, sign into the App Store first so `darwin-rebuild` can install them.
