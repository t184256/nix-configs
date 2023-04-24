{ ... }:

{
  networking.wireguard.interfaces.cashnet = {
    ips = [ "192.168.22.1/24" ];
    listenPort = 51821;
    peers = [
      {
        #endpoint = "cashew";
        allowedIPs = [ "192.168.22.2/32" ];
        publicKey = "DltFpMo7DtqHBDkZop+6B7oVlXeylGyicv1XllFhVRo=";
        persistentKeepalive = 20;
      }
    ];
    privateKeyFile = "/mnt/persist/secrets/wireguard/cashnet-duckweed";
  };
  networking.firewall.allowedUDPPorts = [ 51821 ];

  networking.firewall.allowedTCPPorts = [ 221 ];
  services.xinetd.enable = true;
  services.xinetd.services = [{
      name = "ssh-cashew"; unlisted = true; port = 221;
      server = "/usr/bin/env";  # must be something executable
      extraConfig = "redirect = 192.168.22.2 22";
  }];
}
