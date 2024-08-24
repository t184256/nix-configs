_:

{
  networking.networkmanager.enable = true;
  systemd.network.wait-online.anyInterface = true;

  # accept forwarded SSH/MOSH
  networking.firewall.allowedUDPPortRanges = [ { from = 22700; to = 22799; } ];
  services.sshguard.whitelist = [ "192.168.99.2" ];
}
