{ config, lib, ... }:

{
  hardware.wirelessRegulatoryDatabase = true;
  systemd.network.wait-online.anyInterface = true;
  networking.networkmanager = {
    enable = true;
    wifi.powersave = false;
    ensureProfiles = {
      environmentFiles = [ "/mnt/secrets/network-manager" ];
      profiles = {
        wifi1 = {
          connection = { id = "$SSID1"; type = "wifi"; };
          ipv4.method = "auto";
          ipv6 = { addr-gen-mode = "stable-privacy"; method = "auto"; };
          wifi = { mode = "infrastructure"; ssid = "$SSID1"; };
          wifi-security = { key-mgmt = "wpa-psk"; psk = "$PASS1"; };
        };
        wifi2 = {
          connection = { id = "$SSID2"; type = "wifi"; };
          ipv4.method = "auto";
          ipv6 = { addr-gen-mode = "stable-privacy"; method = "auto"; };
          wifi = { mode = "infrastructure"; ssid = "$SSID2"; };
          wifi-security = { key-mgmt = "wpa-psk"; psk = "$PASS2"; };
        };
      };
    };
  };
  boot.initrd = lib.mkIf config.boot.initrd.systemd.network.enable {
    kernelModules = [ "r8169" ];
    availableKernelModules = [ "r8169" ];
    systemd.network = {
      networks."10-wired" = {
        matchConfig.Name = "enp191s0";
        networkConfig.DHCP = "yes";
        linkConfig.RequiredForOnline = "routable";
        linkConfig.RequiredFamilyForOnline = "ipv4";
      };
      wait-online.anyInterface = true;
      wait-online.timeout = 60;
    };
  };
}
