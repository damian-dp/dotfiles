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
      "ghostty"
      "tailscale-app"
      "zed"
      "cursor"
      "orbstack"
      "gitkraken"
      "arc"
      "google-chrome"
      "raycast"
      "lm-studio"
    ];
    masApps = {
      "Microsoft Outlook" = 985367838;
      "Microsoft Teams" = 1113153706;
    };
    caskArgs.appdir = "/Applications";
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
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
