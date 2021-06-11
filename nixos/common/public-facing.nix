{
  services.sshguard.enable = true;

  # mosh
  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];

  # syncthing
  networking.firewall.allowedTCPPorts = [ 22000 ];
  networking.firewall.allowedUDPPorts = [ 22000 21027 ];
}
