{ ... }:

{
  networking.wireguard.interfaces.cashnet = {
    ips = [ "192.168.22.2/24" ];
    peers = [
      {
        endpoint = "duckweed.unboiled.info:51821";
        allowedIPs = [ "192.168.22.1/32" ];
        publicKey = "9vx798P0nHKUmJz4L3rcbN8XKIkj8BRNRrWl5PAWw0g=";
        persistentKeepalive = 20;
      }
    ];
    privateKeyFile = "/mnt/persist/secrets/wireguard/cashnet-cashew";
  };
}
