{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    "${inputs.nixos-hardware}/onenetbook/4"
    ./hardware-configuration.nix
    ./onemix-keyboard-remap.nix
  ];


  boot.kernelPackages = pkgs.linuxPackages_5_12;
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;  # small /boot
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "lychee"; # Define your hostname.
  networking.networkmanager.enable = true;
  #networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Set your time zone.
  time.timeZone = "Europe/Prague";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  # };

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  environment.systemPackages = with pkgs; [
    firefox-wayland
    alacritty
  ];
  services.openssh.enable = true;

  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  users.users.monk = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  system.role = {
    desktop.enable = true;
    physical.enable = true;
    physical.portable = true;
  };
  home-manager.users.monk = {
    services.syncthing.enable = true;
  };

  system.stateVersion = "21.05";
  home-manager.users.monk.home.stateVersion = "21.05";

  nixpkgs.overlays = [
    (self: super: {
      iio-sensor-proxy =
        if (lib.versionOlder super.iio-sensor-proxy.version "3.0") then
          (super.iio-sensor-proxy.overrideAttrs (oa: rec {
            version = "3.0";
            src = pkgs.fetchFromGitLab {
              domain = "gitlab.freedesktop.org";
              owner = "hadess";
              repo = "iio-sensor-proxy";
              rev = version;
              sha256 = "0ngbz1vkbjci3ml6p47jh6c6caipvbkm8mxrc8ayr6vc2p9l1g49";
            };
          }))
        else super.iio-sensor-proxy;
    })

    (self: super: {
      gnome = super.gnome //
      {
        mutter = super.gnome.mutter.overrideAttrs (oa: {
          patches = oa.patches ++ [
            (pkgs.fetchpatch {
              url = "https://gitlab.gnome.org/GNOME/mutter/-/merge_requests/1846.patch";
              sha256 = "0znhipxdis7f9v8b6sk4fbn42ls8sh12wdw306jsh5xg2gzkcm80";
            })
          ];
        } );
      };
    })
  ];

  # currently manual:
  # * touchpad speed bump in GNOME
  # * screen locking in GNOME
  # * syncthing
  # * thunderbird
}
