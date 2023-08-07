{ ... }:

{
  networking.wireguard.interfaces.cocoanet = {
    ips = [ "192.168.23.2/24" ];
    peers = [
      {
        endpoint = "duckweed.unboiled.info:51823";
        allowedIPs = [ "192.168.23.1/32" ];
        publicKey = "2iWigA6Q03JLozgPsL7Qu9s8tKpZDvUxgLdhEr24dEc=";
        persistentKeepalive = 20;
      }
    ];
    privateKeyFile = "/mnt/persist/secrets/wireguard/cocoanet-cocoa";
  };
}
