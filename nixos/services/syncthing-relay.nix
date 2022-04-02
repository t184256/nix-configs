{ config, ... }:

{
  services.syncthing.relay = {
    enable = true;
    pools = [];
  };
  networking.firewall.allowedTCPPorts = (
    with config.services.syncthing.relay; [ port statusPort ]
  );
}
