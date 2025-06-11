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

  # internal interface
  networking.interfaces."enp1s0" = {
    useDHCP = false;
    ipv4.addresses = [{
      address = "192.168.98.1";
      prefixLength = 24;
    }];
  };
  networking.firewall.allowedUDPPorts = [
    53 67
    47998 47999 48000 48002 48010
  ];
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      domain-needed = true;
      bogus-priv = true;
      no-resolv = true;
      interface = "enp1s0";
      no-dhcpv6-interface = "enp1s0";
      bind-dynamic = true;  # a better bind-interfaces = true;
      listen-address = "192.168.98.1";
      server = [];  # no upstream DNS servers needed
      dhcp-authoritative = true;
      dhcp-option = [
        "option:router"  # no default route, must be ignored anyway
        "option:classless-static-route,192.168.98.0/24,192.168.98.1"  # !
        "option:netmask,255.255.255.0"  # netmask
        "option:dns-server,192.168.98.1"  # DNS
        "option:mtu,1300"  # MTU
      ];
      dhcp-range = "192.168.98.2,192.168.98.2,255.255.255.0,10m";
      dhcp-broadcast = true;
      address = "/meshcentral.unboiled.info./192.168.98.1";
      log-queries = true;
      log-debug = true;
      log-dhcp = true;
    };
  };
  networking.firewall.allowedTCPPorts = [
    443 4433
    2222
    47984 47989 47990 48010
  ];
  services.xinetd.enable = true;
  services.xinetd.services = [
    {
      name = "https-fw"; unlisted = true; port = 443;
      server = "/usr/bin/env";  # must be something executable
      extraConfig = "redirect = 192.168.99.2 443";
    }
    {
      name = "amt-fw"; unlisted = true; port = 4433;
      server = "/usr/bin/env";  # must be something executable
      extraConfig = "redirect = 192.168.99.2 4433";
    }
  ];
  networking.nat = {
    enable = true;
    coolerForwardPorts = true;
    externalInterface = "unboiled";
    internalInterfaces = [ "enp1s0" ];
    forwardPorts = [
     { proto = "tcp"; sourcePort = 2222; destination = "192.168.98.2:22"; }
     { proto = "tcp"; sourcePort = 47984; destination = "192.168.98.2:47984"; }
     { proto = "tcp"; sourcePort = 47989; destination = "192.168.98.2:47989"; }
     { proto = "tcp"; sourcePort = 47990; destination = "192.168.98.2:47990"; }
     { proto = "tcp"; sourcePort = 48010; destination = "192.168.98.2:48010"; }
     { proto = "udp"; sourcePort = 47998; destination = "192.168.98.2:47998"; }
     { proto = "udp"; sourcePort = 47999; destination = "192.168.98.2:47999"; }
     { proto = "udp"; sourcePort = 48000; destination = "192.168.98.2:48000"; }
     { proto = "udp"; sourcePort = 48002; destination = "192.168.98.2:48002"; }
     { proto = "udp"; sourcePort = 48010; destination = "192.168.98.2:48010"; }
    ];
  };
}
