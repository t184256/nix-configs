{ pkgs, ... }:

{
  networking.hostName = "cocoa";

  imports = [
    ../../nixos/profiles/2024.nix
    ./disko.nix
    ./hardware.nix
    ./network.nix
    ../../nixos/services/autosync-voice.nix
    ../../nixos/services/dyndns.nix
    #../../nixos/services/ipfs/cluster-leader.nix
    #../../nixos/services/ipfs/node.nix
    ../../nixos/services/garage.nix
    ../../nixos/services/nebula ../../nixos/services/nebula/2024.nix
    ../../nixos/services/sunshine.nix
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

  system.role = {
    deployer.enable = true;
    desktop.enable = true;
    physical.enable = true;
    physical.portable = true;
    yubikey.enable = true;
  };
  services.syncthing = {
    user = "monk";
    group = "users";
    settings.options.localAnnounceEnabled = true;
  };

  system.stateVersion = "24.05";
  home-manager.users.monk.home.stateVersion = "24.05";

  home-manager.users.monk.neovim.fat = true;
  home-manager.users.monk.language-support = [
    "nix" "bash"
  ];

  home-manager.users.monk.home.persistence."/mnt/storage/sync" = {
    directories = [
      { directory = "code"; method = "symlink"; }
    ];
  };

  services.displayManager.autoLogin = { enable = true; user = "monk"; };

  boot.initrd.systemd.enable = true;

  hardware.display.edid = {
    enable = true;
    modelines = {
       "800x600" = "40 800 840 968 1056 600 601 605 628 -hsync +vsync";
       "1920x1080" = "148.5 1920 2008 2052 2200 1080 1084 1089 1125 +hsync +vsync";
       "2208x1786" = "246.006 2208 2216 2248 2288 1786 1823 1831 1837 +hsync -vsync ratio=16:9";
       "2960x1848" = "468.06 2960 3192 3520 4080 1848 1849 1852 1912 -hsync +vsync ratio=16:9";
       "2960x1848-12" = "988.42 2960 3224 3560 4160 1848 1849 1852 1980 -hsync +vsync ratio=16:9";
       "3840x2160" = "509.443 3840 3848 3880 3920 2160 2208 2216 2222 +hsync -vsync ratio=16:9";
       "3840x2160-3" = "339.57 3840 4080 4496 5152 2160 2161 2164 2197 -hsync +vsync ratio=16:9";
    };
    # If DP-1 has the plug,
    # sudo tee >/dev/null /sys/kernel/debug/dri/1/DP-1/edid_override < /run/current-system/firmware/edid/1920x1080.bin
    # echo off | sudo tee >/dev/null /sys/class/drm/card1-DP-1/status
    # echo detect | sudo tee >/dev/null /sys/class/drm/card1-DP-1/status
  };
}
