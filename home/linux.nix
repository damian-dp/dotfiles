{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/opencode.nix
  ];

  services.opencode.server.enable = true;

  # CLI wrappers and git hooks for headless VMs
  home.file = {
    # Global git hooks (prevent commits/pushes to main)
    ".config/git-hooks/pre-commit" = {
      source = ./dotfiles/shell/git-hooks/pre-commit;
      executable = true;
    };
    ".config/git-hooks/pre-push" = {
      source = ./dotfiles/shell/git-hooks/pre-push;
      executable = true;
    };
    ".local/bin/vercel" = {
      source = ./dotfiles/shell/vercel-wrapper.sh;
      executable = true;
    };
    ".local/bin/pnpm" = {
      source = ./dotfiles/shell/pnpm-wrapper.sh;
      executable = true;
    };
  };
}
