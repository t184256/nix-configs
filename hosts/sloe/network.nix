_:

{
  networking = {
    networkmanager.enable = false;
    interfaces.ens18 = {
      ipv4.addresses =
        [ { address = "77.237.232.57"; prefixLength = 21; } ];
      ipv6.addresses =
        [ { address = "2a02:c206:2207:3890::1"; prefixLength = 64; } ];
    };
    defaultGateway = "77.237.232.1";
    defaultGateway6 = { address = "fe80::1"; interface = "ens18"; };
    nameservers = [ "1.1.1.1" "2a02:c206::1:53" "2a02:c206::2:53" ];
  };
}
