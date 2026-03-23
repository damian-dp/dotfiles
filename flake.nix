{
  description = "Damian's reproducible development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-homebrew, home-manager, nix-darwin, ... }:
    let
      lib = nixpkgs.lib;
      mkDarwinConfiguration = hostModule:
        nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit inputs; };
          modules = [
            nix-homebrew.darwinModules.nix-homebrew
            ./darwin/common.nix
            hostModule
            home-manager.darwinModules.home-manager
            {
              nix-homebrew = {
                enable = true;
                enableRosetta = true;
                autoMigrate = true;
                user = "damian";
              };

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.damian = { lib, ... }: {
                imports = [
                  ./home/core.nix
                  ./home/workstation.nix
                ];
                home.username = "damian";
                home.homeDirectory = lib.mkForce "/Users/damian";
              };
            }
          ];
        };
    in
    {
      # =======================================================================
      # Linux VM (OpenCode Server)
      # =======================================================================
      # Usage: nix run home-manager -- switch --flake .#damian@linux
      #
      # This config enables:
      #   - OpenCode server (systemd service on port 4096)
      #   - Access via Tailscale: http://<tailscale-hostname>:4096
      #
      # First-time setup: OP_SERVICE_ACCOUNT_TOKEN='ops_...' ./bootstrap-vm.sh
      #
      homeConfigurations = {
        "damian@linux" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [
            ./home/core.nix
            ./home/linux.nix
            {
              home.username = "damian";
              home.homeDirectory = "/home/damian";
            }
          ];
        };
        
        "damian@linux-client" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [
            ./home/core.nix
            ./home/modules/opencode.nix
            {
              home.username = "damian";
              home.homeDirectory = "/home/damian";
              services.opencode.server.enable = false;
            }
          ];
        };
      };

      # =======================================================================
      # macOS Workstation
      # =======================================================================
      # Usage: darwin-rebuild switch --flake .#Damian-MBP
      darwinConfigurations = {
        "Damian-MBP" = mkDarwinConfiguration ./darwin/hosts/mbp.nix;
        "Damian-Studio" = mkDarwinConfiguration ./darwin/hosts/studio.nix;
      };

      # =======================================================================
      # Development Shell
      # =======================================================================
      # Usage: nix develop
      devShells = {
        x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
          buildInputs = with nixpkgs.legacyPackages.x86_64-linux; [
            git curl wget htop jq ripgrep fd
          ];
        };
        aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.mkShell {
          buildInputs = with nixpkgs.legacyPackages.aarch64-darwin; [
            git curl wget htop jq ripgrep fd
          ];
        };
      };
    };
}
