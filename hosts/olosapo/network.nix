_:

{
  networking = {
    networkmanager.enable = false;
    interfaces.enp3s0 = {
      ipv4.addresses =
        [ { address = "38.175.203.172"; prefixLength = 22; } ];
      ipv6.addresses =
        [{ address = "2606:a8c0:3:969::a"; prefixLength = 64; } ];
    };
    defaultGateway = "38.175.200.1";
    defaultGateway6 = { address = "2606:a8c0:3::1"; interface = "enp3s0"; };
    nameservers = [ "1.1.1.1" "2606:4700:4700::1111" ];
  };
  boot.kernel.sysctl."net.ipv6.conf.enp3s0.accept_ra_defrtr" = 0;
}
