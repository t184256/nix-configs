_:

{
  services.tang = {
    enable = true;
    listenStream = [ "1449" ];
    ipAddressAllow = [ "any" ];
  };
  networking.firewall.allowedTCPPorts = [ 1449 ];
  environment.persistence."/mnt/persist".directories = [
    "/var/lib/private/tang"
  ];
}
