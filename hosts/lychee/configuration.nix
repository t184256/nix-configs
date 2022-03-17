{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    "${inputs.nixos-hardware}/onenetbook/4"
    ./hardware-configuration.nix
    ./onemix-keyboard-remap.nix
  ];


  boot.kernelPackages = pkgs.linuxPackages_5_15;
  boot.loader.systemd-boot.configurationLimit = 15;  # small-ish /boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.cpu.intel.updateMicrocode = true;
  hardware.opengl.extraPackages = [ pkgs.intel-media-driver ];
  hardware.wirelessRegulatoryDatabase = true;

  zramSwap = { enable = true; memoryPercent = 25; };

  networking.hostName = "lychee"; # Define your hostname.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Prague";

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  systemd.services.depop = {
    wantedBy = [ "powertop.service" ];
    after = [ "powertop.service" ];
    description = "Cancel previous power savings";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo 0 > /sys/module/snd_hda_intel/parameters/power_save'";
    };
  };

  environment.systemPackages = with pkgs; [
    inputs.deploy-rs.defaultPackage.${pkgs.system} hydra-cli
    firefox-wayland
    alacritty
    config.boot.kernelPackages.bpftrace
  ];
  programs.bcc.enable = true;

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
    yubikey.enable = true;
  };
  home-manager.users.monk = {
    services.syncthing.enable = true;
  };

  # unplug Yubikey = lock screen
  services.udev.extraRules =
    let
      script = pkgs.writeScript "usb-script" ''
        uid=$(id -u monk)
        export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus
        ${pkgs.su}/bin/su monk -c 'dbus-send --session --type=method_call \
                                             --dest=org.gnome.ScreenSaver \
                                             /org/gnome/ScreenSaver \
                                             org.gnome.ScreenSaver.Lock'
      '';
    in
      ''
        SUBSYSTEM=="usb", ACTION=="remove", ENV{PRODUCT}=="1050/404/543", \
          RUN+="${pkgs.bash}/bin/bash ${script}"
      '';

  system.stateVersion = "21.05";
  home-manager.users.monk.home.stateVersion = "21.05";

  home-manager.users.monk.language-support = [
    "nix" "bash" "haskell"
  ];

  # currently manual:
  # * touchpad speed bump in GNOME
  # * screen locking in GNOME
  # * syncthing
  # * thunderbird
}
