{ ... }:

{
  networking.wireguard.interfaces.cocoanet = {
    ips = [ "192.168.23.1/24" ];
    listenPort = 51823;
    peers = [
      {
        #endpoint = "cocoa";
        allowedIPs = [ "192.168.23.2/32" ];
        publicKey = "5K1tf3mOkcnjldm08RgK8B+rd+yOiyQ4Hy/epiRLuSg=";
        persistentKeepalive = 20;
      }
    ];
    privateKeyFile = "/mnt/persist/secrets/wireguard/cocoanet-duckweed";
  };
  networking.firewall.allowedUDPPorts = [ 51823 ];

  networking.firewall.allowedTCPPorts = [ 223 ];
  services.xinetd.enable = true;
  services.xinetd.services = [{
      name = "ssh-cocoa"; unlisted = true; port = 223;
      server = "/usr/bin/env";  # must be something executable
      extraConfig = "redirect = 192.168.23.2 22";
  }];
}
