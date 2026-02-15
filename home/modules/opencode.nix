{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.opencode;
in
{
  options.services.opencode = {
    server = {
      enable = mkEnableOption "OpenCode server";

      port = mkOption {
        type = types.int;
        default = 4096;
        description = "Port for the OpenCode server";
      };
    };
  };

  config = mkMerge [
    (mkIf (pkgs.stdenv.isLinux && cfg.server.enable) {
      systemd.user.startServices = "sd-switch";

      # OpenCode web server (no password - access restricted via Tailscale)
      systemd.user.services.opencode = {
        Unit = {
          Description = "OpenCode Server";
        };

        Service = {
          Type = "simple";
          ExecStart = "%h/.opencode/bin/opencode web --hostname 0.0.0.0 --port ${toString cfg.server.port}";
          Restart = "on-failure";
          RestartSec = "5";
          Environment = [
            "HOME=%h"
            "PATH=%h/.opencode/bin:%h/.bun/bin:%h/.local/bin:%h/.nix-profile/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin:/usr/bin:/bin"
          ];
        };

        Install = {
          WantedBy = [ "default.target" ];
        };
      };

      home.packages = with pkgs; [
        jq
      ];
    })
  ];
}
