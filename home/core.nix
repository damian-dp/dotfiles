{ config, pkgs, lib, ... }:

# Core configuration - shared by all machines (Linux thin + macOS workstation)
{
  home.username = lib.mkDefault "damian";  # Overridden per-platform in flake.nix
  home.stateVersion = "24.05";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # Disable manual generation (fixes builtins.toFile warning)
  manual.html.enable = false;
  manual.manpages.enable = false;
  manual.json.enable = false;

  # =============================================================================
  # Packages
  # =============================================================================
  home.packages = with pkgs; [
    # Core CLI tools
    git
    gh
    curl
    wget
    htop
    btop
    jq
    tree
    tmux

    # Search & navigation
    ripgrep
    fd
    # fzf, eza, zoxide configured via programs.* for shell integration

    # Git tools
    delta
    lazygit

    # Python tooling
    uv
    gettext

    # Node.js + package managers
    nodejs_22
    pnpm
    bun

    # LSP servers (used by Claude Code plugins)
    nodePackages.typescript-language-server
    typescript
    biome

    ] ++ lib.optionals stdenv.isDarwin [
      postgresql_17
    ] ++ [

    # Networking
    tailscale
    # Note: mosh installed via apt outside Nix when needed (needs to be in system PATH for mosh-server)
  ] ++ lib.optionals stdenv.isLinux [
    # Linux gets Docker Engine/Compose directly.
    # macOS uses the Docker-compatible CLI/runtime provided by OrbStack.app.
    docker
    docker-compose
  ];

  # =============================================================================
  # Dotfiles (symlinked to nix store - read-only)
  # =============================================================================
  home.file = {
    ".zshrc.local".source = ./dotfiles/zshrc;
    ".p10k.zsh".source = ./dotfiles/p10k.zsh;
    ".npmrc".text = ''
      @tilt-legal:registry=https://npm.pkg.github.com
      //npm.pkg.github.com/:_authToken=''${GH_NPM_TOKEN}
      always-auth=true
    '';
    # Platform-specific 1Password signing paths (included by programs.git)
    ".gitconfig-macos".source = ./dotfiles/gitconfig-macos;
    ".gitconfig-linux".source = ./dotfiles/gitconfig-linux;
    ".ssh/config".text = builtins.readFile ./dotfiles/ssh_config
      + lib.optionalString pkgs.stdenv.isDarwin ''

        # =============================================================================
        # 1Password SSH Agent (macOS only)
        # =============================================================================
        Host *
        	IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

        # =============================================================================
        # VM (macOS only - port forwarding via vm() shell function)
        # =============================================================================
        Host vm
        	HostName dev-vm-damian.taild53693.ts.net
      ''
      + lib.optionalString pkgs.stdenv.isLinux ''

        # =============================================================================
        # GitHub (Linux VMs - use key file, no 1Password agent)
        # =============================================================================
        Host github.com
        	IdentityFile ~/.ssh/id_ed25519_signing
      '';
    ".tmux.conf".source = ./dotfiles/tmux.conf;

    # Codex/OpenCode runtime configs are rendered explicitly by
    # scripts/render-secret-configs.sh because they contain secret-backed values.

    # Shell functions
    ".config/shell/commit.sh".source = ./dotfiles/shell/commit.sh;
    ".local/bin/pnpm" = {
      source = ./dotfiles/shell/pnpm-wrapper.sh;
      executable = true;
    };

    # Claude CLI - CLAUDE.md symlinked (instructions only, never written)
    ".claude/CLAUDE.md".source = ./dotfiles/claude/CLAUDE.md;
    # Note: settings.json is overwritten every rebuild (see activation script)

    # Codex CLI - AGENTS.md symlinked (instructions only, never written)
    ".codex/AGENTS.md".source = ./dotfiles/codex/AGENTS.md;
    # Note: config.toml is rendered explicitly by scripts/render-secret-configs.sh

    # Warp launch configurations (symlinked - single source of truth)
    ".warp/launch_configurations/cubitt-mobius.yaml".source = ./dotfiles/warp/cubitt-mobius.yaml;
  };

  # =============================================================================
  # Zsh
  # =============================================================================
  programs.zsh = {
    enable = true;

    # Source nix daemon for standalone home-manager on Linux
    # This ensures nix-profile/bin is in PATH before zsh starts
    # (nix-darwin handles this automatically, but standalone home-manager doesn't)
    envExtra = lib.optionalString pkgs.stdenv.isLinux ''
      # Source nix daemon for PATH setup (standalone home-manager on Linux)
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi
    '';

    # Source custom zshrc for additional config (p10k, secrets, etc.)
    initContent = ''
      [[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
    '';
  };

  # Add external CLI paths (tools installed outside nix)
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.opencode/bin"
    "$HOME/.antigravity/antigravity/bin"
  ];

  # =============================================================================
  # Oh My Zsh + Powerlevel10k
  # =============================================================================
  programs.zsh.oh-my-zsh = {
    enable = true;
    plugins = [ "git" ];
  };

  programs.zsh.plugins = [
    {
      name = "powerlevel10k";
      src = pkgs.zsh-powerlevel10k;
      file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
    }
  ];

  # =============================================================================
  # Tool Integrations (with shell hooks)
  # =============================================================================
  # Using programs.* for automatic shell integration instead of just packages

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    extraOptions = [ "--group-directories-first" "--icons" ];
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;  # Better nix integration
  };

  # =============================================================================
  # Git (using built-in module - single source of truth)
  # =============================================================================
  programs.git = {
    enable = true;

    signing = {
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEo5Gg7jA4PuksRMUCl3fGu/B0nt8IpVbMzzbqGOQ4px";
      signByDefault = true;
    };

    settings = {
      user.name = "Damian Petrov";
      user.email = "hello@damianpetrov.com";
      gpg.format = "ssh";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.editor = "vim";
    };

    # Platform-specific 1Password signing paths
    includes = [
      {
        condition = "gitdir:/Users/";
        path = "~/.gitconfig-macos";
      }
      {
        condition = "gitdir:/home/";
        path = "~/.gitconfig-linux";
      }
    ];
  };

  # GitHub CLI (installed via packages, config managed by gh itself)

  # =============================================================================
  # Session Variables
  # =============================================================================
  home.sessionVariables = {
    EDITOR = if pkgs.stdenv.isDarwin then "zed --wait" else "vim";
    VISUAL = if pkgs.stdenv.isDarwin then "zed --wait" else "vim";
    DOTFILES = "$HOME/code/dotfiles";
  };

  # =============================================================================
  # Shell Aliases
  # =============================================================================
  home.shellAliases = {
    ll = "ls -la";
    gs = "git status";
    gp = "git push";
    gl = "git pull";
    ta = "tmux attach -t";
    tl = "tmux ls";
    tn = "tmux new -s";
    lg = "lazygit";

    # 1Password CLI sign-in (personal + work accounts)
    signin = ''eval "$(op signin --account my)" && eval "$(op signin --account tiltlegal)"'';
  };

  # =============================================================================
  # Bash (for exec to zsh on Linux)
  # =============================================================================
  programs.bash = {
    enable = true;
    initExtra = ''
      # If running interactively and zsh is available, switch to it
      if [[ $- == *i* ]] && command -v zsh &>/dev/null; then
        exec zsh
      fi
    '';
  };

  # =============================================================================
  # Activation Scripts
  # =============================================================================
  home.activation = {
    # =========================================================================
    # Writable App Configs (overwritten every rebuild - dotfiles is source of truth)
    # =========================================================================
    copyWritableConfigs = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Cursor editor settings (macOS only; copied, not symlinked - VS Code atomic writes break symlinks)
      if [ "$(uname -s)" = "Darwin" ]; then
        $DRY_RUN_CMD mkdir -p "$HOME/Library/Application Support/Cursor/User"
        $DRY_RUN_CMD cp ${../configs/cursor/settings.json} "$HOME/Library/Application Support/Cursor/User/settings.json"
        $DRY_RUN_CMD chmod 644 "$HOME/Library/Application Support/Cursor/User/settings.json"
        $DRY_RUN_CMD cp ${../configs/cursor/keybindings.json} "$HOME/Library/Application Support/Cursor/User/keybindings.json"
        $DRY_RUN_CMD chmod 644 "$HOME/Library/Application Support/Cursor/User/keybindings.json"
      fi

      # Claude CLI settings
      $DRY_RUN_CMD mkdir -p "$HOME/.claude"
      $DRY_RUN_CMD cp ${./dotfiles/claude/settings.json} "$HOME/.claude/settings.json"
      $DRY_RUN_CMD chmod 644 "$HOME/.claude/settings.json"

      # OpenCode package metadata (runtime config is rendered explicitly)
      $DRY_RUN_CMD mkdir -p "$HOME/.config/opencode"
      $DRY_RUN_CMD cp ${./dotfiles/opencode/package.json} "$HOME/.config/opencode/package.json"
      $DRY_RUN_CMD chmod 644 "$HOME/.config/opencode/package.json"

    '';
  };
}
