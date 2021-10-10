{ lib, ... }:

{
  boot.tmpOnTmpfs = lib.mkDefault true;
  systemd.enableEmergencyMode = false;
  services.journald.extraConfig = "SystemMaxUse=5%";
}
