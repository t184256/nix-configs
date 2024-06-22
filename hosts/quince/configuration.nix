{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./secureboot.nix
    ../../nixos/services/ipfs/cluster-leader.nix
    ../../nixos/services/ipfs/node.nix
    ../../nixos/services/nebula
  ];

  users.mutableUsers = false;
  users.users.monk.hashedPasswordFile = "/mnt/persist/secrets/login/monk";
  users.users.root.hashedPasswordFile = "/mnt/persist/secrets/login/root";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  hardware.cpu.intel.updateMicrocode = true;
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
  hardware.wirelessRegulatoryDatabase = true;
  networking.networkmanager.wifi.powersave = false;

  systemd.targets.storage.after = [ "mnt-storage.mount" ];

  zramSwap = { enable = true; memoryPercent = 50; };

  networking.hostName = "quince";
  networking.networkmanager.enable = true;
  systemd.network.wait-online.anyInterface = true;

  # Set your time zone.
  time.timeZone = "Europe/Prague";

  #services.kubo.settings.Datastore.StorageMax = "20G";

  # accept forwarded SSH/MOSH
  networking.firewall.allowedUDPPortRanges = [ { from = 22600; to = 22699; } ];
  services.sshguard.whitelist = [ "192.168.99.2" ];

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;
  system.role.physical.enable = true;
  system.role.yubikey.enable = true;
  #home-manager.users.monk = {
  #  services.syncthing.enable = true;
  #};

  system.stateVersion = "23.11";
  home-manager.users.monk.home.stateVersion = "23.11";

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
      (let mode = { mode = "0755"; }; in [
        { file = "/etc/ssh/ssh_host_rsa_key"; parentDirectory = mode; }
        { file = "/etc/ssh/ssh_host_rsa_key.pub"; parentDirectory = mode; }
        { file = "/etc/ssh/ssh_host_ed25519_key"; parentDirectory = mode; }
        { file = "/etc/ssh/ssh_host_ed25519_key.pub"; parentDirectory = mode; }
      ]) ++ [
        "/etc/machine-id"
      ];
    # TODO: allowlisting of ~
  };
}
