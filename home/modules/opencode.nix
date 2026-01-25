{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.opencode;
in
{
  options.services.opencode = {
    server = {
      enable = mkEnableOption "OpenCode web server with Tailscale";
      
      port = mkOption {
        type = types.int;
        default = 5551;
        description = "Port for the OpenCode web server";
      };
      
      hostname = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Hostname to bind the server to";
      };
    };
  };

  config = mkMerge [
    (mkIf (pkgs.stdenv.isLinux && cfg.server.enable) {
      systemd.user.startServices = "sd-switch";
      
      systemd.user.services.opencode-server = {
        Unit = {
          Description = "OpenCode Web Server";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };

        Service = {
          Type = "simple";
          ExecStart = "%h/.opencode/bin/opencode web --hostname ${cfg.server.hostname} --port ${toString cfg.server.port}";
          ExecStartPost = "${pkgs.bash}/bin/bash -c 'sleep 5 && ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 http://localhost:${toString cfg.server.port}'";
          ExecStopPost = "${pkgs.tailscale}/bin/tailscale serve --https=443 off";
          Restart = "always";
          RestartSec = "10";
          Environment = [
            "HOME=%h"
            "PATH=%h/.opencode/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin:/usr/bin:/bin"
          ];
        };

        Install = {
          WantedBy = [ "default.target" ];
        };
      };

      home.packages = with pkgs; [
        tailscale
        jq
      ];
    })
  ];
}
