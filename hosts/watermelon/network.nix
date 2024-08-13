_:

{
  networking = {
    networkmanager.enable = false;
    interfaces.enX0.ipv4.addresses = [
      { address = "104.152.210.200"; prefixLength = 24; }
    ];
    defaultGateway = "104.152.210.1";
    nameservers = [ "1.1.1.1" ];
  };
}
