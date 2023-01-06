{ config, pkgs, inputs, ... }:

{
  imports = [
    "${inputs.nixos-hardware}/onenetbook/4"
    ./hardware-configuration.nix
    ./onemix-keyboard-remap.nix
  ];

  users.mutableUsers = false;
  users.users.monk.passwordFile = "/mnt/persist/secrets/login/monk";
  users.users.root.passwordFile = "/mnt/persist/secrets/login/root";

  boot.loader.systemd-boot.configurationLimit = 15;  # small-ish /boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  hardware.cpu.intel.updateMicrocode = true;
  hardware.opengl.extraPackages = [ pkgs.intel-media-driver ];
  hardware.wirelessRegulatoryDatabase = true;

  services.logind.lidSwitch = "suspend-then-hibernate";
  systemd.sleep.extraConfig = "HibernateDelaySec=90m";

  zramSwap = { enable = true; memoryPercent = 50; };

  networking.hostName = "lychee"; # Define your hostname.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Prague";

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };
  #hardware.pulseaudio.enable = true;
  #systemd.services.depop = {
  #  wantedBy = [ "powertop.service" ];
  #  after = [ "powertop.service" ];
  #  description = "Cancel previous power savings";
  #  serviceConfig = {
  #    Type = "oneshot";
  #    RemainAfterExit = "yes";
  #    ExecStart = "${pkgs.bash}/bin/bash -c 'echo 0 > /sys/module/snd_hda_intel/parameters/power_save'";
  #  };
  #};

  #nixpkgs.overlays = [ (import ../../overlays/plymouth-better-bgrt.nix) ];
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

  home-manager.users.monk.home.packages = with pkgs; [
    inputs.deploy-rs.defaultPackage.${pkgs.system}
    alacritty freerdp
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

  system.stateVersion = "22.05";
  home-manager.users.monk.home.stateVersion = "22.05";

  home-manager.users.monk.language-support = [
    "nix" "bash" "python"
  ];

  # currently manual:
  # * touchpad speed bump in GNOME
  # * screen locking in GNOME
  # * syncthing
  # * thunderbird

  programs.adb.enable = true;
  virtualisation.waydroid.enable = true;
  users.extraGroups.plugdev.members = [ "monk" ];
  networking.firewall.allowedTCPPorts = [ 3389 ];  # RDP

  environment.persistence."/mnt/persist" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/etc/NetworkManager"
      "/var/lib/NetworkManager"
      "/var/lib/alsa"
      "/var/lib/bluetooth"
      "/var/lib/boltd"
      "/var/lib/systemd"
      "/var/lib/upower"
      "/var/lib/waydroid"
      "/var/log"
    ];
    files =
      (let mode = { mode = "0700"; }; in [
        { file = "/etc/ssh/ssh_host_rsa_key"; parentDirectory = mode; }
        { file = "/etc/ssh/ssh_host_rsa_key.pub"; parentDirectory = mode; }
        { file = "/etc/ssh/ssh_host_ed25519_key"; parentDirectory = mode; }
        { file = "/etc/ssh/ssh_host_ed25519_key.pub"; parentDirectory = mode; }
      ]) ++ [
        "/etc/machine-id"
      ];
    # TODO: allowlisting of ~
  };
}
