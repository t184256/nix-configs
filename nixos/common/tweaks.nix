{ ... }:

{
  boot.tmpOnTmpfs = true;
  systemd.enableEmergencyMode = false;
  services.journald.extraConfig = "SystemMaxUse=5%";
}
