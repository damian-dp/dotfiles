{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/opencode.nix
  ];

  services.opencode.server.enable = true;

  # CLI wrappers for headless VMs (inject 1Password tokens)
  home.file = {
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
