{ pkgs, ... }:

{
  networking.hostName = "sloe";

  imports = [
    ./disko.nix
    ./hardware.nix
    ./network.nix
    ../../nixos/services/nebula ../../nixos/services/nebula/2024.nix
    ../../nixos/services/syncthing.nix
  ];

  boot.loader.grub.enable = true;  # sigh

  environment.systemPackages = with pkgs; [
    curl
    git
  ];

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

  services.openssh.hostKeys =
    [ { path = "/run/credentials/sshd.service/ed25519"; type = "ed25519"; } ];
  systemd.services.sshd.serviceConfig.LoadCredential =
    "ed25519:/mnt/secrets/sshd/ed25519";

  environment.persistence."/mnt/persist" = {
    hideMounts = true;
    directories = [
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
