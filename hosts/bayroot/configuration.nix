{ lib, ... }:

{
  networking.hostName = "bayroot";

  imports = [
    ./hardware-configuration.nix
    ../../nixos/services/dyndns.nix
    ../../nixos/services/nebula
  ];

  boot.loader.systemd-boot.configurationLimit = 5;  # small-ish /boot
  boot.loader.systemd-boot.enable = true;
  boot.kernelParams = [ "console=ttyS0" ];

  networking.useDHCP = false;
  services.cloud-init = {
    enable = true;
    network.enable = true;
    settings = {
      cloud_init_modules = lib.mkForce [];
      cloud_config_modules = lib.mkForce [];
      cloud_final_modules = lib.mkForce [];
    };
  };
  environment.etc."systemd/network/10-cloud-init-ens2.network.d/local.conf".text = ''
    [Network]
    DNS = 2001:67c:2960::64
    [DHCPv4]
    UseDNS=false
  '';
  services.resolved.fallbackDns = [ "2a00:1098:2c::1" ];

  zramSwap = { enable = true; memoryPercent = 50; };

  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 21d";
  nixpkgs.flake.setNixPath = false;  # save disk space
  nixpkgs.flake.setFlakeRegistry = false;  # save disk space

  users.mutableUsers = false;
  users.users.monk.hashedPasswordFile = "/mnt/persist/secrets/login/monk";
  users.users.root.hashedPasswordFile = "/mnt/persist/secrets/login/root";

  systemd.services.systemd-machine-id-commit.enable = false;

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;

  system.stateVersion = "23.11";
  home-manager.users.monk.home.stateVersion = "23.11";

  environment.persistence."/mnt/persist" = {
    hideMounts = true;
    directories = [
      "/var/lib/nixos"
      "/var/log"
    ];
    files =
      let
        mode = { mode = "0755"; };
      in
      [
        "/etc/machine-id"
        { file = "/etc/ssh/ssh_host_rsa_key"; parentDirectory = mode; }
        { file = "/etc/ssh/ssh_host_rsa_key.pub"; parentDirectory = mode; }
        { file = "/etc/ssh/ssh_host_ed25519_key"; parentDirectory = mode; }
        { file = "/etc/ssh/ssh_host_ed25519_key.pub"; parentDirectory = mode; }
      ];
    users.monk = {
      directories = [
        ".local/share/pygments-cache"
        ".local/share/xonsh"
      ];
      files = [
        ".bash_history"
      ];
    };
  };
}
