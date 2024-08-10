{ pkgs, ... }:

{
  networking.hostName = "loquat";

  imports = [
    ./hardware-configuration.nix
    ../../nixos/services/akkoma.nix
    ../../nixos/services/dns.nix
    #../../nixos/services/fedifetcher.nix
    ../../nixos/services/ipfs/cluster-leader.nix
    ../../nixos/services/ipfs/node.nix
    ../../nixos/services/git.nix
    ../../nixos/services/hydra.nix
    ../../nixos/services/lemmy.nix
    ../../nixos/services/mail.nix
    ../../nixos/services/nebula
    ../../nixos/services/nix-on-droid.nix
    ../../nixos/services/www-bare.nix
    ../../nixos/services/www-monk.nix
    ../../nixos/services/xmpp.nix
    ../../nixos/services/yousable-serve.nix
  ];

  boot.loader.grub = { enable = true; device = "/dev/sda"; };

  time.timeZone = "Europe/Prague";

  networking.useDHCP = false;
  networking.resolvconf.enable = false;
  services.resolved.enable = true;
  systemd.network.enable = true;
  systemd.network.networks.enp0s18 = {
    matchConfig.Name = "enp0s18";
    enable = true;
    address = [ "38.242.239.104/19" "2a02:c206:2101:9233::1/64" ];
    gateway = [ "38.242.224.1" "fe80::1" ];
    networkConfig.LinkLocalAddressing = "ipv6";
    #DHCP = "ipv6";
    #networkConfig.DHCP = "ipv6";
    #networkConfig.IPv6AcceptRA = "yes";
    #ipv6AcceptRAConfig.DHCPv6Client = "always";
  };

  users.mutableUsers = false;
  users.users.monk.hashedPasswordFile = "/mnt/persist/secrets/login/monk";
  users.users.root.hashedPasswordFile = "/mnt/persist/secrets/login/root";

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;

  zramSwap = { enable = true; memoryPercent = 50; };

  services.kubo.settings.Datastore.StorageMax = "20G";

  services.hydra.buildMachinesFiles = [(
    pkgs.writeText "machines" ''
      localhost x86_64-linux - 1 1 kvm,nixos-test,big-parallel,benchmark  -
    ''
  )];
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
  systemd.services.nix-daemon.serviceConfig = {
    CPUAffinity = "0-3";
    MemoryHigh = "14G"; MemoryMax = "15G";
  };
  #systemd.services.yousable-back.serviceConfig.CPUAffinity = "0-3";
  #systemd.services.syncthing.serviceConfig.CPUAffinity = "0-3";
  systemd.services.gitea.serviceConfig.CPUAffinity = "0-3";
  systemd.services.akkoma.serviceConfig.CPUAffinity = "0-2";
  systemd.services.lemmy.serviceConfig.CPUAffinity = "0-2";

  home-manager.users.monk.language-support = [ ];

  home-manager.users.monk.services.syncthing.enable = true;

  system.stateVersion = "22.05";
  home-manager.users.monk.home.stateVersion = "22.05";

  environment.persistence."/mnt/persist" = {
    hideMounts = true;
    directories = [
      "/srv/nix-on-droid"
      "/srv/monk"
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
