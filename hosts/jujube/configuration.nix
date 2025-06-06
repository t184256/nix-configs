{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    "${inputs.nixos-hardware}/onenetbook/4"
    ./hardware-configuration.nix
    ../lychee/onemix-keyboard-remap.nix
    ../../nixos/services/nebula
    ../../nixos/services/nps.nix  # rather condition on interactive or something
  ];

  users.mutableUsers = false;
  users.users.monk.hashedPasswordFile = "/mnt/persist/secrets/login/monk";
  users.users.root.hashedPasswordFile = "/mnt/persist/secrets/login/root";

  boot.loader.systemd-boot.configurationLimit = 15;  # small-ish /boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  hardware.cpu.intel.updateMicrocode = true;
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
  hardware.wirelessRegulatoryDatabase = true;

  services.logind.lidSwitch = "suspend-then-hibernate";
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=45m
    HibernateOnACPower=true
  '';

  zramSwap = { enable = true; memoryPercent = 50; };

  networking.hostName = "jujube"; # Define your hostname.
  networking.networkmanager.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # the closest NixOS currently has to silent boot:
  boot.plymouth.enable = true;
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet" "splash" "i915.fastboot=1" "loglevel=3"
    "rd.systemd.show_status=false" "rd.udev.log_level=3" "udev.log_priority=3"
  ];
  console.earlySetup = false;
  boot.loader.timeout = 0;

  services.displayManager.autoLogin = { enable = true; user = "monk"; };

  home-manager.users.monk.home.packages = with pkgs; [
    inputs.deploy-rs.defaultPackage.${pkgs.system}
    alacritty freerdp openvpn
  ];

  services.openssh.enable = true;

  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  system.role = {
    desktop.enable = true;
    physical.enable = true;
    physical.portable = true;
    yubikey.enable = true;
  };
  #home-manager.users.monk = {
  #  services.syncthing.enable = true;
  #};

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
        DRIVER=="vkms", SUBSYSTEM=="platform", TAG-="mutter-device-ignore"
      '';

  system.stateVersion = "24.05";
  home-manager.users.monk.home.stateVersion = "24.05";

  home-manager.users.monk.roles.mua = true;
  home-manager.users.monk.neovim.fat = true;
  home-manager.users.monk.language-support = [
    "nix" "bash" "prose" "python" "typst" "yaml"
  ];

  # currently manual:
  # * touchpad speed bump in GNOME
  # * screen locking in GNOME
  # * syncthing
  # * thunderbird

  # let's try to fix suspend
  #boot.kernelPackages = pkgs.linuxPackages_latest;
  hardware.sensor.iio.enable = lib.mkForce false;
  systemd.services.systemd-suspend = {
    environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";
  };

  programs.adb.enable = true;
  users.extraGroups.plugdev.members = [ "monk" ];
  networking.firewall.allowedTCPPorts = [ 3389 47984 47989 48010  ];
  networking.firewall.allowedUDPPorts = [ 47998 47999 48000 48002 ];

  systemd.services.systemd-machine-id-commit.enable = false;

  environment.persistence."/mnt/persist" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/etc/NetworkManager"
      "/var/lib/NetworkManager"
      "/var/lib/alsa"
      "/var/lib/bluetooth"
      "/var/lib/boltd"
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/lib/upower"
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

  ###

  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = [ pkgs.android-studio ];
}
