# Apps to Install

Manual installation list for macOS workstation. Install these after running `darwin-rebuild switch`.

## Essential

| App | Source | Notes |
|-----|--------|-------|
| [1Password](https://1password.com/downloads/mac/) | Direct / App Store | Password manager, SSH agent |
| [Ghostty](https://ghostty.org/) | Direct | Terminal emulator |
| [Tailscale](https://tailscale.com/download) | Direct / App Store | VPN mesh network |

## Development

| App | Source | Notes |
|-----|--------|-------|
| [Zed](https://zed.dev/) | Direct | Primary editor |
| [Cursor](https://cursor.sh/) | Direct | AI-assisted editor |
| [OrbStack](https://orbstack.dev/) | Direct | Docker & Linux VMs |
| [GitKraken](https://www.gitkraken.com/) | Direct | Git GUI (optional) |

## Browsers

| App | Source | Notes |
|-----|--------|-------|
| [Arc](https://arc.net/) | Direct | Primary browser |
| [Chrome](https://www.google.com/chrome/) | Direct | Testing/compatibility |

## Productivity

| App | Source | Notes |
|-----|--------|-------|
| [Raycast](https://www.raycast.com/) | Direct | Spotlight replacement |
| Microsoft Outlook | App Store | Email |
| Microsoft Teams | App Store | Communication |

## Utilities

| App | Source | Notes |
|-----|--------|-------|
| [LM Studio](https://lmstudio.ai/) | Direct | Local LLMs |

## CLI Tools (installed separately)

These are installed outside of Nix:

```bash
# NVM (Node Version Manager)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# pnpm
curl -fsSL https://get.pnpm.io/install.sh | sh -

# Bun
curl -fsSL https://bun.sh/install | bash

# uv (Python)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Post-Install Setup

### 1Password SSH Agent

After installing 1Password, enable the SSH agent:
1. Open 1Password → Settings → Developer
2. Enable "Use the SSH Agent"
3. The agent socket is at `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`

### Ghostty

Config is managed by dotenv at `~/Library/Application Support/com.mitchellh.ghostty/config`

### Zed & Cursor

Configs are managed by dotenv:
- Zed: `~/.config/zed/settings.json`
- Cursor: `~/Library/Application Support/Cursor/User/settings.json`
