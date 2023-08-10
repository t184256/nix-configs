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

  networking.firewall = {
    allowedUDPPorts = [ 51823 ];
    allowedTCPPorts = [ 223 ];
    allowedUDPPortRanges = [ { from = 22300; to = 22399; } ];
  };
  networking.nat = {
    enable = true;
    externalInterface = "ens2";
    coolerForwardPorts = true;
    forwardPorts = [
      { proto = "tcp"; sourcePort = 223; destination = "192.168.23.2:22"; }
      {
        proto = "udp";
        sourcePort = "22300:22399";
        destination = "192.168.23.2:22300-22399/22300";
      }
    ];
  };
}
