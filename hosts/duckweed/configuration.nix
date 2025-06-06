{ pkgs, ... }:

{
  networking.hostName = "duckweed";

  imports = [
    ./hardware-configuration.nix
    ../../nixos/services/dns.nix
    ../../nixos/services/forward-cocoa.nix
    ../../nixos/services/forward-quince.nix
    ../../nixos/services/ipfs/gateway.nix
    ../../nixos/services/ipfs/node.nix
    ../../nixos/services/ipfs/micro.nix
    ../../nixos/services/meshcentral.nix
    ../../nixos/services/microsocks.nix
    ../../nixos/services/nebula
    ../../nixos/services/syncthing-relay.nix
    ../../nixos/services/wireguard-nl.nix
  ];

  boot.loader.systemd-boot.configurationLimit = 10;  # small-ish /boot
  boot.loader.systemd-boot.enable = true;
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/A2EB-3AB7";
    fsType = "vfat";
    options = [ "nofail" ];
  };
  boot.kernelParams = [ "console=ttyS0" ];

  zramSwap = { enable = true; memoryPercent = 50; };

  nix.settings.auto-optimise-store = true;  # it's tight on disk space
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

  system.stateVersion = "21.05";
  home-manager.users.monk.home.stateVersion = "21.05";

  environment.persistence."/mnt/persist" = {
    hideMounts = true;
    directories = [
      "/var/lib/acme"
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
