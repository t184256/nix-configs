{ pkgs, ... }:

{
  networking.hostName = "cocoa";

  imports = [
    ../../nixos/profiles/2024.nix
    ./disko.nix
    ./hardware.nix
    ./network.nix
    #../../nixos/services/dyndns.nix
    #../../nixos/services/ipfs/cluster-leader.nix
    #../../nixos/services/ipfs/node.nix
    ../../nixos/services/nebula ../../nixos/services/nebula/2024.nix
    ../../nixos/services/syncthing.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  hardware.cpu.intel.updateMicrocode = true;
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
  hardware.wirelessRegulatoryDatabase = true;

  #services.kubo.settings.Datastore.StorageMax = "20G";

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

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;
  system.role = {
    #desktop.enable = true;
    physical.enable = true;
    physical.portable = true;
    yubikey.enable = true;
  };
  services.syncthing = { user = "monk"; group = "users"; };

  system.stateVersion = "24.05";
  home-manager.users.monk.home.stateVersion = "24.05";

  home-manager.users.monk.neovim.fat = true;
  home-manager.users.monk.language-support = [
    "nix" "bash"
  ];

  environment.persistence."/mnt/persist" = {
    directories = [
      "/etc/NetworkManager"
      "/var/lib/NetworkManager"
    #  "/var/lib/alsa"
    #  "/var/lib/bluetooth"
    #  "/var/lib/boltd"
    #  "/var/lib/systemd"
    #  "/var/lib/upower"
    #  "/var/lib/waydroid"
    ];
  };

  services.displayManager.autoLogin = { enable = true; user = "monk"; };

  boot.initrd.systemd.enable = true;
}
