{ config, pkgs, ... }:

{
  networking.hostName = "quince";

  imports = [
    ./disko.nix
    ./hardware.nix
    ./network.nix
    ./secureboot.nix
    #../../nixos/services/ipfs/cluster-leader.nix
    #../../nixos/services/ipfs/node.nix
    ../../nixos/services/nebula ../../nixos/services/nebula/2024.nix
    ../../nixos/services/syncthing.nix
  ];

  #boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  hardware.cpu.intel.updateMicrocode = true;
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  systemd.targets.storage.after = [ "mnt-storage.mount" ];

  nixpkgs.flake.setNixPath = false;  # save disk space
  nixpkgs.flake.setFlakeRegistry = false;  # save disk space

  users.mutableUsers = false;
  users.users.monk.hashedPasswordFile = "/mnt/secrets/login/monk";
  users.users.root.hashedPasswordFile = "/mnt/secrets/login/root";

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;

  home-manager.users.monk.home.stateVersion = "24.05";
  system.stateVersion = "24.05";

  boot.loader.systemd-boot.netbootxyz.enable = true;
  zramSwap = { enable = true; memoryPercent = 50; };

  #services.kubo.settings.Datastore.StorageMax = "20G";

  services.openssh.hostKeys =
    [ { path = "/run/credentials/sshd.service/ed25519"; type = "ed25519"; } ];
  systemd.services.sshd.serviceConfig.LoadCredential =
    "ed25519:/mnt/secrets/sshd/ed25519";

  # accept forwarded SSH/MOSH
  networking.firewall.allowedUDPPortRanges = [ { from = 22600; to = 22699; } ];
  services.sshguard.whitelist = [ "192.168.99.2" ];

  system.role.physical.enable = true;
  #system.role.yubikey.enable = true;

  environment.persistence."/mnt/persist" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/etc/NetworkManager"
      "/var/lib/NetworkManager"
      "/var/lib/nixos"
      "/var/log"
    ];
    files =
      [
        "/etc/machine-id"
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
