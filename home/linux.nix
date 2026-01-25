{ config, pkgs, lib, ... }:

{
  systemd.user.services.opencode-manager = {
    Unit = {
      Description = "OpenCode Manager - Web UI for OpenCode";
      After = [ "docker.service" "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "simple";
      WorkingDirectory = "%h/.config/opencode-manager";
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose --profile remote up";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose --profile remote down";
      Restart = "always";
      RestartSec = "10";
      Environment = [
        "PATH=${pkgs.docker}/bin:${pkgs.docker-compose}/bin:/usr/bin:/bin"
      ];
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  home.packages = with pkgs; [
    docker-compose
  ];
}
