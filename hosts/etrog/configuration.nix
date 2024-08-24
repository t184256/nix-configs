{ pkgs, ... }:

{
  networking.hostName = "etrog";

  imports = [
    ./disko.nix
    ./hardware.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  environment.systemPackages = with pkgs; [
    curl
    git
  ];

  nixpkgs.flake.setNixPath = false;  # save disk space
  nixpkgs.flake.setFlakeRegistry = false;  # save disk space

  users.mutableUsers = false;
  users.users.monk.hashedPasswordFile = "/mnt/persist/secrets/login/monk";
  users.users.root.hashedPasswordFile = "/mnt/persist/secrets/login/root";

  services.openssh.enable = true;

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;

  home-manager.users.monk.home.stateVersion = "24.05";
  system.stateVersion = "24.05";

  boot.loader.systemd-boot.netbootxyz.enable = true;
  zramSwap = { enable = true; memoryPercent = 50; };

  services.openssh.hostKeys =
    [ { path = "/run/credentials/sshd.service/ed25519"; type = "ed25519"; } ];
  systemd.services.sshd.serviceConfig.LoadCredential =
    "ed25519:/mnt/persist/secrets/sshd/ed25519";

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
