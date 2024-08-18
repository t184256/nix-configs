_:

{
  networking = {
    networkmanager.enable = false;
    interfaces.enX0 = {
      ipv4.addresses =
        [ { address = "104.152.210.200"; prefixLength = 24; } ];
      ipv6.addresses =
        [ { address = "2602:ffd5:1:1b0::1"; prefixLength = 36; } ];
    };
    defaultGateway = "104.152.210.1";
    defaultGateway6 = { address = "2602:ffd5:1:100::1"; interface = "enX0"; };
    nameservers = [ "1.1.1.1" "2606:4700:4700::1111" ];
  };
}
