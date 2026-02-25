{ config, pkgs, lib, ... }:

# Workstation configuration - macOS desktop apps and their configs
{
  # =============================================================================
  # Additional Packages (workstation-only)
  # =============================================================================
  home.packages = with pkgs; [
    # Additional tools for workstation
    bat

    # Fonts (for terminal rendering)
    nerd-fonts.meslo-lg
    nerd-fonts.jetbrains-mono
  ];

  # =============================================================================
  # App Configurations (symlinked to nix store - portable but read-only)
  # =============================================================================
  # Edit source files in dotfiles repo, then rebuild to apply changes
  # Note: Cursor settings are in core.nix activation script (needs writable files)

  # Ghostty terminal
  home.file."Library/Application Support/com.mitchellh.ghostty/config".source =
    ../home/dotfiles/ghostty.conf;

  # Cursor editor - deployed via activation script (not symlinked)
  # VS Code/Cursor uses atomic writes which break symlinks, so we copy instead
  # See core.nix copyWritableConfigs activation script

  # =============================================================================
  # Zed Editor (using built-in module - portable)
  # =============================================================================
  programs.zed-editor = {
    enable = true;

    # Immutable - edit these settings here, rebuild to apply
    userSettings = {
      bottom_dock_layout = "contained";
      tab_bar = {
        show_tab_bar_buttons = true;
      };
      tabs = {
        file_icons = false;
        git_status = false;
      };
      title_bar = {
        show_menus = false;
        show_branch_icon = false;
      };
      project_panel = {
        button = true;
      };
      minimap = {
        show = "never";
      };
      toolbar = {
        code_actions = false;
      };
      git_panel = {
        tree_view = true;
        sort_by_path = false;
      };
      agent = {
        default_model = {
          provider = "copilot_chat";
          model = "gpt-5-mini";
        };
        play_sound_when_agent_done = true;
        always_allow_tool_actions = true;
        model_parameters = [];
      };
      calls = {
        share_on_join = true;
      };
      audio = {
        "experimental.rodio_audio" = true;
      };
      autosave = {
        after_delay = {
          milliseconds = 0;
        };
      };
      show_wrap_guides = true;
      buffer_line_height = "comfortable";
      buffer_font_family = ".ZedMono";
      terminal = {
        font_family = "MesloLGS NF";
      };
      file_types = {
        tailwindcss = [
          "tailwind.css"
          "*.css"
        ];
      };
      soft_wrap = "editor_width";
      tab_size = 2;
      base_keymap = "Cursor";
      icon_theme = {
        mode = "system";
        light = "Zed (Default)";
        dark = "Zed (Default)";
      };
      ui_font_size = 15.0;
      buffer_font_size = 13.0;
      theme = {
        mode = "system";
        light = "One Light";
        dark = "One Dark";
      };
    };

    userKeymaps = [
      {
        context = "Workspace";
        bindings = {
          "cmd-shift-g" = "git_panel::ToggleFocus";
        };
      }
    ];
  };

  # =============================================================================
  # FZF (workstation gets full integration)
  # =============================================================================
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
    ];
  };

  # =============================================================================
  # Bat (better cat)
  # =============================================================================
  programs.bat = {
    enable = true;
    config = {
      theme = "Solarized (dark)";
      style = "numbers,changes";
    };
  };
}
