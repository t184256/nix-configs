{ lib, ... }:

{
  boot.tmp.useTmpfs = lib.mkDefault true;
  systemd.enableEmergencyMode = false;
  systemd.extraConfig = ''
    DefaultTimeoutStopSec=30s
  '';
  services.journald.extraConfig = "SystemMaxUse=5%";
}
