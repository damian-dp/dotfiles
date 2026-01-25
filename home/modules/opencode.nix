{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.opencode;
in
{
  options.services.opencode = {
    server = {
      enable = mkEnableOption "OpenChamber web server with Tailscale";
      
      port = mkOption {
        type = types.int;
        default = 3000;
        description = "Port for the OpenChamber web server";
      };
      
      password = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional password to protect the web UI";
      };
    };
  };

  config = mkMerge [
    (mkIf (pkgs.stdenv.isLinux && cfg.server.enable) {
      systemd.user.startServices = "sd-switch";
      
      systemd.user.services.openchamber = {
        Unit = {
          Description = "OpenChamber Web Server";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };

        Service = {
          Type = "simple";
          ExecStart = let
            passwordFlag = if cfg.server.password != null 
              then "--ui-password ${cfg.server.password}" 
              else "";
          in "%h/.local/bin/openchamber --port ${toString cfg.server.port} ${passwordFlag}";
          ExecStartPost = "${pkgs.bash}/bin/bash -c 'sleep 10 && ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 http://localhost:${toString cfg.server.port}'";
          ExecStopPost = "${pkgs.tailscale}/bin/tailscale serve --https=443 off";
          Restart = "always";
          RestartSec = "10";
          Environment = [
            "HOME=%h"
            "PATH=%h/.local/bin:%h/.opencode/bin:%h/.nvm/versions/node/v22.16.0/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin:${pkgs.nodejs}/bin:/usr/bin:/bin"
          ];
        };

        Install = {
          WantedBy = [ "default.target" ];
        };
      };

      home.packages = with pkgs; [
        tailscale
        jq
        nodejs
      ];
    })
  ];
}
