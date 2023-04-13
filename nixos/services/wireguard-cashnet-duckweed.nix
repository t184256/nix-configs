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
      }
    ];
    privateKeyFile = "/mnt/persist/secrets/wireguard/cashnet-duckweed";
  };
  networking.firewall.allowedUDPPorts = [ 51821 ];
}
