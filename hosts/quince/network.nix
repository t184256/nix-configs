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

  # accept forwarded SSH/MOSH
  networking.firewall.allowedUDPPortRanges = [ { from = 22600; to = 22699; } ];
  services.sshguard.whitelist = [ "192.168.99.2" ];

  environment.persistence."/mnt/persist" = {
    directories = [
      "/etc/NetworkManager"
      "/var/lib/NetworkManager"
    ];
  };
}
