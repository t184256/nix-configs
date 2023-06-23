{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../nixos/services/sunshine.nix
    ../../nixos/services/wireguard-cashnet-cashew.nix
  ];

  users.mutableUsers = false;
  users.users.monk.passwordFile = "/mnt/persist/secrets/login/monk";
  users.users.root.passwordFile = "/mnt/persist/secrets/login/root";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  hardware.cpu.intel.updateMicrocode = true;
  hardware.opengl.extraPackages = [ pkgs.intel-media-driver ];
  hardware.wirelessRegulatoryDatabase = true;

  #zramSwap = { enable = true; memoryPercent = 50; };

  networking.hostName = "cashew";
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Prague";

  # Enable sound with pipewire.
  #sound.enable = true;
  #hardware.pulseaudio.enable = false;
  #security.rtkit.enable = true;
  #services.pipewire = {
  #  enable = true;
  #  alsa.enable = true;
  #  alsa.support32Bit = true;
  #  pulse.enable = true;
  #};

  environment.systemPackages = with pkgs; [
    sunshine
  ];
  users.users.monk.extraGroups = [ "video" "input" ];

  #home-manager.users.monk.home.packages = with pkgs; [
  #  inputs.deploy-rs.defaultPackage.${pkgs.system}
  #];

  services.openssh.enable = true;

  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  nix.settings.cores = 3;  # we're not in a hurry
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "2G";
  systemd.services.nix-daemon.environment.TMPDIR = "/nix/tmp";  # large builds
  system.activationScripts.nixtmpdir.text = "mkdir -p /nix/tmp";
  systemd.services.nix-daemon.serviceConfig = {
    CPUAffinity = "2-5"; MemoryHigh = "14G"; MemoryMax = "15G";
  };
  nix.gc.automatic = true;

  system.role = {
    desktop.enable = true;
    physical.enable = true;
    physical.portable = true;
    yubikey.enable = true;
  };

  system.stateVersion = "22.05";
  home-manager.users.monk.home.stateVersion = "22.05";

  #home-manager.users.monk.language-support = [
  #  "nix" "bash"
  #];

  environment.persistence."/mnt/persist" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/etc/NetworkManager"
      "/var/lib/NetworkManager"
    #  "/var/lib/alsa"
    #  "/var/lib/bluetooth"
    #  "/var/lib/boltd"
    #  "/var/lib/systemd"
    #  "/var/lib/upower"
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

  services.xserver.displayManager.autoLogin = { enable = true; user = "monk"; };
  services.xserver.displayManager.gdm.autoLogin.delay = 4;
  # ^ IDK why this is needed, but otherwise it sometimes starts X
  boot.loader.timeout = 0;
  console.earlySetup = false;
  boot.kernelParams = [
    # "quiet" "splash" "loglevel=3"
    #"rd.systemd.show_status=false" "rd.udev.log_level=3" "udev.log_priority=3"
    "i915.fastboot=1"
  ];

  services.thermald = {
    enable = true;
    debug = true;
    configFile = ./thermald.xml;
  };

  users.users.builder = { group = "builder"; isSystemUser = true; useDefaultShell = true; };
  users.groups.builder = {};
  users.users.builder.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJXOeZe1VelK/Qt9XQCrpMcp4xu4i+K69Sf8+8PpboLd hydra.unboiled.info"
  ];
  nix.settings.trusted-users = [ "builder" ];

  #services.udev.extraRules = ''
  #  ACTION=="add", SUBSYSTEM=="drm", KERNEL=="card0", TAG+="systemd"
  #'';
  #systemd.services.fake-display = {
  #  description = "fake-display";
  #  requires = [ "modprobe@drm.service" "dev-dri-card0.device" ];
  #  after = [ "modprobe@drm.service" "dev-dri-card0.device" ];
  #  wantedBy = [ "display-manager.service" ];
  #  before = [ "display-manager.service" ];
  #  environment = {
  #    HOME = "/var/lib/sunshine";
  #    WAYLAND_DISPLAY = "wayland-0";
  #    XDG_RUNTIME_DIR = "/run/user/1000";
  #  };
  #  serviceConfig = {
  #    Type = "simple";
  #    ExecStart = "${pkgs.bash}/bin/bash -c '"
  #      + "${pkgs.coreutils}/bin/echo on-digital"
  #      + " > /sys/class/drm/card0-DP-1/status"
  #      + "'";
  #  };
  #};
}
