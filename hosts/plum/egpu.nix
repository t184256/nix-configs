{ pkgs, ... }:

# Thunderbolt eGPU (BoostR 01 / RX 7600M XT), compute only.
# Needs BIOS 7E70v2A52+, host_reset=N (below) and cable plugged in on boot.
# The rule keeps it out of D3cold: a failed resume loops on the Titan Ridge hub.
{
  services.udev.extraRules = ''
    SUBSYSTEM=="pci", ATTR{vendor}=="0x1002", ATTR{device}=="0x7480", \
      ATTR{d3cold_allowed}="0", ATTR{power/control}="on"
  '';

  boot.kernelPackages = pkgs.linuxPackages_latest;  # tested on 7.3.0
  boot.extraModprobeConfig = "options thunderbolt host_reset=N";
}
