{ ... }:

{
  networking.nat = {
    enable = true;
    internalInterfaces = [ "junglenet" ];
    externalInterface = "ens2";
  };
  networking.wireguard.interfaces.junglenet = {
    ips = [ "192.168.21.1/24" ];
    listenPort = 51820;
    peers = [
      {
        #endpoint = "<gl.inet jungle>";
        allowedIPs = [ "192.168.21.2/32" ];
        publicKey = "WVUFjmv6nEawCT8mjXBW0DRlyMJrYJxMox0zdADS7i4=";
        persistentKeepalive = 5;
      }
    ];
    privateKeyFile = "/mnt/persist/secrets/wireguard/junglenet-nl";
  };
  networking.firewall.allowedUDPPorts = [ 51820 ];
}
