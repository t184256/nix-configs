{ pkgs, ... }:

{
  networking.hostName = "loquat";

  imports = [
    ./hardware-configuration.nix
    ../../nixos/services/akkoma.nix
    ../../nixos/services/dns.nix
    ../../nixos/services/git.nix
    ../../nixos/services/hydra.nix
    ../../nixos/services/lemmy.nix
    ../../nixos/services/mail.nix
    ../../nixos/services/nix-on-droid.nix
    ../../nixos/services/xmpp.nix
    ../../nixos/services/yousable.nix
  ];

  boot.loader.grub = { enable = true; device = "/dev/sda"; };

  time.timeZone = "Europe/Prague";

  users.mutableUsers = false;
  users.users.monk.passwordFile = "/mnt/persist/secrets/login/monk";
  users.users.root.passwordFile = "/mnt/persist/secrets/login/root";

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;

  zramSwap = { enable = true; memoryPercent = 50; };

  services.hydra.buildMachinesFiles = [(
    pkgs.writeText "machines" ''
      localhost x86_64-linux - 1 1 kvm,nixos-test,big-parallel,benchmark  -
    ''
  )];
  programs.ssh.extraConfig = ''
    Host cashew
      Hostname duckweed.unboiled.info
      Port 221
  '';
  programs.ssh.knownHosts.cashew = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILUp0oeg2rVY1trfHcMPglSkujft1r6C6D/K/+7RV5yj";
    hostNames = [ "[duckweed.unboiled.info]:221" ];
  };
  nix.buildMachines = [ {
    hostName = "localhost";
    system = "x86_64-linux";
    supportedFeatures = ["kvm" "nixos-test" "big-parallel" "benchmark"];
    maxJobs = 1;  # we're not in a hurry, we save RAM/SWAP
  } ];
  nix.settings.cores = 3;  # we're not in a hurry, we save RAM/SWAP
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "2G";
  systemd.services.nix-daemon.environment.TMPDIR = "/nix/tmp";  # large builds
  system.activationScripts.nixtmpdir.text = "mkdir -p /nix/tmp";
  nix.gc.automatic = true;
  #nix.settings.auto-optimise-store = true;
  systemd.services.nix-daemon.serviceConfig = {
    CPUAffinity = "0-3";
    MemoryHigh = "14G"; MemoryMax = "15G";
  };
  systemd.services.yousable-back.serviceConfig.CPUAffinity = "0-3";
  systemd.services.akkoma.serviceConfig.CPUAffinity = "0-2";

  home-manager.users.monk.language-support = [ "nix" "bash" ];

  home-manager.users.monk.services.syncthing.enable = true;

  system.stateVersion = "22.05";
  home-manager.users.monk.home.stateVersion = "22.05";

  environment.persistence."/mnt/persist" = {
    hideMounts = true;
    directories = [
      "/srv/nix-on-droid"
      "/var/lib/acme"
      "/var/log"
    ];
    files =
      let
        mode = { mode = "0700"; };
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
        ".config/syncthing"
        ".local/share/pygments-cache"
        ".local/share/xonsh"
        ".sync"
      ];
      files = [
        ".bash_history"
      ];
    };
  };
}
