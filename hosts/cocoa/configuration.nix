{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../nixos/services/ipfs/node.nix
    ../../nixos/services/nebula
  ];

  users.mutableUsers = false;
  users.users.monk.hashedPasswordFile = "/mnt/persist/secrets/login/monk";
  users.users.root.hashedPasswordFile = "/mnt/persist/secrets/login/root";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  hardware.cpu.intel.updateMicrocode = true;
  hardware.opengl.extraPackages = [ pkgs.intel-media-driver ];
  hardware.wirelessRegulatoryDatabase = true;

  #zramSwap = { enable = true; memoryPercent = 50; };

  networking.hostName = "cocoa";
  networking.networkmanager.enable = true;
  systemd.network.wait-online.anyInterface = true;

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

  #home-manager.users.monk.home.packages = with pkgs; [
  #  inputs.deploy-rs.defaultPackage.${pkgs.system}
  #];

  services.openssh.enable = true;

  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  # accept forwarded SSH/MOSH
  networking.firewall.allowedUDPPortRanges = [ { from = 22700; to = 22799; } ];
  services.sshguard.whitelist = [ "192.168.99.2" ];

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;
  system.role = {
    #desktop.enable = true;
    physical.enable = true;
    physical.portable = true;
    yubikey.enable = true;
  };
  #home-manager.users.monk = {
  #  services.syncthing.enable = true;
  #};

  system.stateVersion = "23.05";
  home-manager.users.monk.home.stateVersion = "23.05";

  #home-manager.users.monk.language-support = [
  #  "nix" "bash"
  #];

  environment.persistence."/mnt/persist" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/etc/NetworkManager"
      "/var/lib/NetworkManager"
      "/var/lib/nixos"
    #  "/var/lib/alsa"
    #  "/var/lib/bluetooth"
    #  "/var/lib/boltd"
    #  "/var/lib/systemd"
    #  "/var/lib/upower"
    #  "/var/lib/waydroid"
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

  environment.systemPackages = with pkgs; [ keyutils ];

  services.xserver.displayManager.autoLogin = { enable = true; user = "monk"; };
}
