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
    # Note: .gitconfig is copied (not symlinked) so gh auth can write to it
    ".gitconfig-macos".source = ./dotfiles/gitconfig-macos;
    ".gitconfig-linux".source = ./dotfiles/gitconfig-linux;
    ".ssh/config".source = ./dotfiles/ssh_config;
    ".tmux.conf".source = ./dotfiles/tmux.conf;

    # OpenCode
    ".config/opencode/opencode.jsonc".source = ./dotfiles/opencode/opencode.jsonc;
    ".config/opencode/oh-my-opencode.json".source = ./dotfiles/opencode/oh-my-opencode.json;
    ".config/opencode/package.json".source = ./dotfiles/opencode/package.json;

    # Shell functions (commit, opencode wrapper)
    ".config/shell/commit.sh".source = ./dotfiles/shell/commit.sh;
    ".config/shell/opencode.sh".source = ./dotfiles/shell/opencode.sh;

    # Claude CLI (CLAUDE.md is read-only global instructions)
    ".claude/CLAUDE.md".source = ./dotfiles/claude/CLAUDE.md;
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
  # Session Variables
  # =============================================================================
  home.sessionVariables = {
    EDITOR = "zed --wait";
    VISUAL = "zed --wait";
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
  # Writable Config Files (copied, not symlinked, so tools can modify them)
  # =============================================================================
  home.activation = {
    copyGitconfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Copy gitconfig so gh auth setup-git can write to it
      $DRY_RUN_CMD cp -f ${./dotfiles/gitconfig} $HOME/.gitconfig
      $DRY_RUN_CMD chmod 644 $HOME/.gitconfig
    '';

    # =========================================================================
    # AI Coding CLIs (installed outside Nix for auto-updates)
    # =========================================================================
    installAiClis = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Ensure nix-provided tools are in PATH for install scripts
      export PATH="${pkgs.curl}/bin:${pkgs.wget}/bin:${pkgs.coreutils}/bin:$PATH"
      
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
    # Writable App Configs (copied so apps can modify them)
    # =========================================================================
    copyAppConfigs = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Claude CLI settings (only copy if not exists - preserves user's accumulated permissions)
      if [ ! -f "$HOME/.claude/settings.json" ]; then
        $DRY_RUN_CMD mkdir -p "$HOME/.claude"
        $DRY_RUN_CMD cp ${./dotfiles/claude/settings.json} "$HOME/.claude/settings.json"
        $DRY_RUN_CMD chmod 644 "$HOME/.claude/settings.json"
      fi

      # GitHub CLI config (only copy if not exists)
      if [ ! -f "$HOME/.config/gh/config.yml" ]; then
        $DRY_RUN_CMD mkdir -p "$HOME/.config/gh"
        $DRY_RUN_CMD cp ${./dotfiles/gh/config.yml} "$HOME/.config/gh/config.yml"
        $DRY_RUN_CMD chmod 644 "$HOME/.config/gh/config.yml"
      fi

      # Warp launch configurations (only copy if not exists)
      if [ ! -d "$HOME/.warp/launch_configurations" ]; then
        $DRY_RUN_CMD mkdir -p "$HOME/.warp/launch_configurations"
      fi
      for config in ${./dotfiles/warp}/*.yaml; do
        filename=$(basename "$config")
        if [ ! -f "$HOME/.warp/launch_configurations/$filename" ]; then
          $DRY_RUN_CMD cp "$config" "$HOME/.warp/launch_configurations/$filename"
        fi
      done
    '';
  };
}
