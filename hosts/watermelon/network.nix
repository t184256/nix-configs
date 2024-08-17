_:

{
  networking = {
    networkmanager.enable = false;
    interfaces.enX0 = {
      ipv4.addresses =
        [ { address = "104.152.210.200"; prefixLength = 24; } ];
      ipv6.addresses =
        [ { address = "2a02:c206:6898:d2c8::1"; prefixLength = 64; } ];
    };
    defaultGateway = "104.152.210.1";
    defaultGateway6 = { address = "fe80::1"; interface = "enX0"; };
    nameservers = [ "1.1.1.1" "2606:4700:4700::1111" ];
  };
}
