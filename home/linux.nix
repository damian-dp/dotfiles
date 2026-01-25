{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/opencode.nix
  ];

  services.opencode.server.enable = true;
}
