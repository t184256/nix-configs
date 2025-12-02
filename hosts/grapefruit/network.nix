_:

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
}
