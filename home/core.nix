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

    # Networking
    tailscale
    # Note: mosh installed via apt in bootstrap.sh (needs to be in system PATH for mosh-server)
  ] ++ lib.optionals stdenv.isLinux [
    # Docker (macOS uses OrbStack instead)
    docker
    docker-compose
  ];

  # =============================================================================
  # Dotfiles (symlinked to nix store - read-only)
  # =============================================================================
  home.file = {
    ".zshrc.local".source = ./dotfiles/zshrc;
    ".p10k.zsh".source = ./dotfiles/p10k.zsh;
    # Platform-specific 1Password signing paths (included by programs.git)
    ".gitconfig-macos".source = ./dotfiles/gitconfig-macos;
    ".gitconfig-linux".source = ./dotfiles/gitconfig-linux;
    ".ssh/config".source = ./dotfiles/ssh_config;
    ".tmux.conf".source = ./dotfiles/tmux.conf;

    # OpenCode configs are all copy-once (see activation script)
    # OpenCode and its plugins need write access to these files

    # Shell functions
    ".config/shell/commit.sh".source = ./dotfiles/shell/commit.sh;

    # Claude CLI - CLAUDE.md symlinked (instructions only, never written)
    ".claude/CLAUDE.md".source = ./dotfiles/claude/CLAUDE.md;
    # Note: settings.json is copy-once (see activation script) because Claude writes permissions to it

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
    "$HOME/.bun/bin"
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
    # AI Coding CLIs (installed outside Nix for auto-updates)
    # =========================================================================
    installAiClis = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Ensure nix-provided tools are in PATH for install scripts
      export PATH="${pkgs.curl}/bin:${pkgs.wget}/bin:${pkgs.coreutils}/bin:${pkgs.gnutar}/bin:${pkgs.gzip}/bin:${pkgs.unzip}/bin:$PATH"

      # Claude Code (check by file path, not command -v)
      if [ ! -x "$HOME/.local/bin/claude" ]; then
        echo "Installing Claude Code..."
        $DRY_RUN_CMD ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh | $DRY_RUN_CMD bash
      fi

      # OpenCode (check by file path)
      if [ ! -x "$HOME/.opencode/bin/opencode" ]; then
        echo "Installing OpenCode..."
        $DRY_RUN_CMD ${pkgs.curl}/bin/curl -fsSL https://opencode.ai/install | $DRY_RUN_CMD bash
      fi

      # Bun (JavaScript runtime & package manager)
      if [ ! -x "$HOME/.bun/bin/bun" ]; then
        echo "Installing Bun..."
        $DRY_RUN_CMD ${pkgs.curl}/bin/curl -fsSL https://bun.sh/install | $DRY_RUN_CMD bash
      fi

      # Turborepo (installed via bun)
      if [ -x "$HOME/.bun/bin/bun" ]; then
        if ! "$HOME/.bun/bin/bun" pm ls -g 2>/dev/null | grep -q "turbo@"; then
          echo "Installing Turborepo..."
          $DRY_RUN_CMD "$HOME/.bun/bin/bun" add -g turbo
        fi
      fi

      # Codex (OpenAI) - requires npm
      if ! command -v codex &>/dev/null && command -v npm &>/dev/null; then
        echo "Installing Codex..."
        $DRY_RUN_CMD npm install -g @openai/codex
      fi
    '';

    # =========================================================================
    # Writable App Configs (copy-once - apps write to these files)
    # =========================================================================
    copyWritableConfigs = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Claude CLI settings (writes permissions)
      if [ ! -f "$HOME/.claude/settings.json" ]; then
        $DRY_RUN_CMD mkdir -p "$HOME/.claude"
        $DRY_RUN_CMD cp ${./dotfiles/claude/settings.json} "$HOME/.claude/settings.json"
        $DRY_RUN_CMD chmod 644 "$HOME/.claude/settings.json"
      fi

      # OpenCode configs (all copy-once - OpenCode and plugins need write access)
      $DRY_RUN_CMD mkdir -p "$HOME/.config/opencode"
      if [ ! -f "$HOME/.config/opencode/opencode.json" ]; then
        $DRY_RUN_CMD cp ${./dotfiles/opencode/opencode.json} "$HOME/.config/opencode/opencode.json"
        $DRY_RUN_CMD chmod 644 "$HOME/.config/opencode/opencode.json"
      fi
      if [ ! -f "$HOME/.config/opencode/oh-my-opencode.json" ]; then
        $DRY_RUN_CMD cp ${./dotfiles/opencode/oh-my-opencode.json} "$HOME/.config/opencode/oh-my-opencode.json"
        $DRY_RUN_CMD chmod 644 "$HOME/.config/opencode/oh-my-opencode.json"
      fi
      if [ ! -f "$HOME/.config/opencode/package.json" ]; then
        $DRY_RUN_CMD cp ${./dotfiles/opencode/package.json} "$HOME/.config/opencode/package.json"
        $DRY_RUN_CMD chmod 644 "$HOME/.config/opencode/package.json"
      fi

    '';
  };
}
