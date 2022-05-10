{ config, pkgs, ... }:

{
  imports = [
    #./real-pc.nix
    ./laptop-X2x0-jap-keyboard-remap.nix
    #<nixos-hardware/lenovo/thinkpad/x220>
    #<nixos-hardware/common/pc/laptop>
    #<nixos-hardware/common/pc/laptop/acpi_call.nix>
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Due to WLAN firmware issues and Ethernet link detection issues
  # Brokenness matrix, cold boot:
  # D = disk not found, even before LUKS password prompt
  # K = keyboard is not responsive during LUKS password prompt
  # W = wifi firmware fails to load
  # B = bluetooth can sustain (re)connection to trackball over 1h
  # E = Ethernet works OK
  # . = OK, X = fails
  #                                               # |DKWBE|
  #boot.kernelPackages = pkgs.linuxPackages_4_14; # |...X?|  used previously
  #boot.kernelPackages = pkgs.linuxPackages_4_19; # |..X.?|
  #boot.kernelPackages = pkgs.linuxPackages_5_4;
  #boot.kernelPackages = pkgs.linuxPackages_5_8;
  boot.kernelPackages = pkgs.linuxPackages_5_11;  # luks/wifi works, random lockups

  environment.systemPackages = with pkgs; [
    hdparm
    lm_sensors
  ];

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;

  #powerManagement.cpuFreqGovernor = "ondemand";

  powerManagement.powertop.enable = true;  # tlp misses a few tunables

  #services.tlp.enable = true;
  #services.tlp.extraConfig = ''
  #  DISK_DEVICES="sda sdb"
  #  DISK_APM_LEVEL_ON_AC="1 keep"
  #  DISK_APM_LEVEL_ON_BAT="1 keep"
  #  DISK_SPINDOWN_TIMEOUT_ON_BAT="24 keep"
  #'';

  #services.thinkfan.enable = true;
  #services.thinkfan.sensors = "hwmon /run/thinkfan_temp1_input (0,0,10)";
  #systemd.services.thinkfan.preStart = ''
  #  for SENSOR in /sys/class/hwmon/hwmon*/temp1_input; do
  #    ln -sf $SENSOR /run/thinkfan_temp1_input
  #  done
  #'';

  powerManagement.powerDownCommands = ''
    if ${pkgs.gnugrep}/bin/grep -q '\bLID\b.*\benabled\b' /proc/acpi/wakeup; then
          echo LID > /proc/acpi/wakeup
    fi;
  '';

  #security.rngd.enable = true;  # TPM supposedly has a hardware RNG

  #boot.extraModprobeConfig = ''
  #  options iwlwifi bt_coex_active=0 power_save=Y
  #  options iwldvm force_cam=N
  #'';  # https://github.com/dancek/dotfiles/blob/master/nixos/thinkpad-x220i/configuration.nix

  services.fprintd.enable = true;
  security.pam.services.login.fprintAuth = true;
  security.pam.services.lightdm.fprintAuth = true;
  security.pam.services.kde.fprintAuth = true;
  security.pam.services.xscreensaver.fprintAuth = true;

  hardware.trackpoint.enable = true;
  hardware.trackpoint.sensitivity = 210;
  hardware.trackpoint.speed = 150;

  hardware.opengl.extraPackages = with pkgs; [ vaapiIntel libvdpau-va-gl vaapiVdpau ];
}
