{ config, pkgs, ... }:

{
  # Basic system configuration for VMs/servers
  
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  nixpkgs.config.allowUnfree = true;

  # Boot (adjust based on VM type)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "development-vm";
  networking.networkmanager.enable = true;

  # Timezone
  time.timeZone = "UTC";

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    git
    tmux
    curl
    wget
    htop
  ];

  # Enable Tailscale
  services.tailscale.enable = true;

  # SSH server with hardened settings
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
    };
  };

  # Firewall - only allow SSH (via Tailscale)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];  # No public ports
    trustedInterfaces = [ "tailscale0" ];  # Trust Tailscale
  };

  # User account
  users.users.damian = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEo5Gg7jA4PuksRMUCl3fGu/B0nt8IpVbMzzbqGOQ4px"
    ];
  };

  # Allow sudo without password for wheel group
  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "24.05";
}
