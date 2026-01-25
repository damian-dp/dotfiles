{ config, pkgs, lib, ... }:

{
  systemd.user.services.opencode-server = {
    Unit = {
      Description = "OpenCode Web Server";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "%h/.opencode/bin/opencode web --hostname 0.0.0.0 --port 5551";
      ExecStartPost = "${pkgs.tailscale}/bin/tailscale serve --bg --https=443 http://localhost:5551";
      ExecStopPost = "${pkgs.tailscale}/bin/tailscale serve --https=443 off";
      Restart = "always";
      RestartSec = "10";
      Environment = [
        "HOME=%h"
        "PATH=%h/.opencode/bin:/usr/bin:/bin"
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
}
