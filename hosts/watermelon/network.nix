_:

{
  networking = {
    networkmanager.enable = false;
    interfaces.enX0 = {
      ipv4.addresses =
        [ { address = "104.152.210.200"; prefixLength = 24; } ];
      ipv6.addresses =
        [ { address = "2602:ffd5:907:2::2"; prefixLength = 64; } ];
    };
    defaultGateway = "104.152.210.1";
    defaultGateway6 = { address = "2602:ffd5:1:907:2::1"; interface = "enX0"; };
    nameservers = [ "1.1.1.1" "2606:4700:4700::1111" ];
  };
}
