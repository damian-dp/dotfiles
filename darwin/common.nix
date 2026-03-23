{ pkgs, ... }:

{
  # =============================================================================
  # Nix Settings (managed externally, not by nix-darwin)
  # =============================================================================
  nix.enable = false;
  documentation.enable = false;
  
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # =============================================================================
  # Homebrew / App Store
  # =============================================================================
  homebrew = {
    enable = true;
    brews = [ "mas" ];
    casks = [
      "1password"
      "1password-cli"
      "ghostty"
      "tailscale-app"
      "zed"
      "cursor"
      "orbstack"
      "google-chrome"
      "raycast"
      "t3-code"
      "microsoft-outlook"
      "microsoft-teams"
      "microsoft-excel"
      "microsoft-word"
      "onedrive"
      "affinity-designer"
      "affinity-photo"
      "affinity-publisher"
      "bambu-studio"
      "betterdisplay"
      "chatgpt"
      "claude"
      "codex-app"
      "codexbar"
      "discord"
      "figma"
      "linear-linear"
      "logitune"
      "notion"
      "nucleo"
      "setapp"
      "spotify"
      "warp"
    ];
    masApps = {
      "Caffeinated" = 1362171212;
      "1Password for Safari" = 1569813296;
      "BetterJSON" = 1511935951;
      "WhatFont" = 1437138382;
    };
    caskArgs.appdir = "/Applications";
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "uninstall";
    };
  };

  # =============================================================================
  # System Packages
  # =============================================================================
  environment.systemPackages = with pkgs; [
    # Core tools installed system-wide
    git
    vim
  ];

  # =============================================================================
  # macOS System Preferences
  # =============================================================================
  system.defaults = {
    # Dock
    dock = {
      autohide = false;
      show-recents = false;
      minimize-to-application = false;
    };

    # Finder
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      FXEnableExtensionChangeWarning = false;
    };

    # Global
    NSGlobalDomain = {
      AppleInterfaceStyleSwitchesAutomatically = true;
      AppleShowScrollBars = "WhenScrolling";
      ApplePressAndHoldEnabled = false;
    };

    # Mouse scaling (separate domain)
    ".GlobalPreferences" = {
      "com.apple.mouse.scaling" = 1.5;
    };

    # Login window
    loginwindow = {
      GuestEnabled = false;
    };

    # Screenshots
    screencapture = {
      target = "clipboard";
      type = "png";
    };

    # Text Replacements (type @@ -> email, etc.)
    CustomUserPreferences = {
      NSGlobalDomain = {
        NSUserDictionaryReplacementItems = [
          { on = 1; replace = "@@"; "with" = "hello@damianpetrov.com"; }
          { on = 1; replace = "@&"; "with" = "damian.petrov@tilt.legal"; }
          { on = 1; replace = "omw"; "with" = "On my way!"; }
        ];
      };
    };
  };

  # =============================================================================
  # Services
  # =============================================================================
  services.tailscale.enable = true;

  # =============================================================================
  # Primary User (required for user-specific settings)
  # =============================================================================
  system.primaryUser = "damian";

  # =============================================================================
  # Security
  # =============================================================================
  security.pam.services.sudo_local.touchIdAuth = true;

  # =============================================================================
  # System State Version
  # =============================================================================
  system.stateVersion = 5;
}
