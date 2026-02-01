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

      # OpenCode server - password loaded from credentials file
      # Create password: mkdir -p ~/.config/opencode/credentials && echo "your-password" > ~/.config/opencode/credentials/server_password
      systemd.user.services.opencode = {
        Unit = {
          Description = "OpenCode Server";
        };

        Service = {
          Type = "simple";
          ExecStart = "/bin/sh -c 'OPENCODE_SERVER_PASSWORD=$(cat \"$CREDENTIALS_DIRECTORY/opencode_password\") exec %h/.opencode/bin/opencode serve --hostname 0.0.0.0 --port ${toString cfg.server.port}'";
          LoadCredential = "opencode_password:%h/.config/opencode/credentials/server_password";
          Restart = "on-failure";
          RestartSec = "5";
          Environment = [
            "HOME=%h"
            "PATH=%h/.opencode/bin:%h/.bun/bin:%h/.local/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin:/usr/bin:/bin"
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
