{
  # mosh
  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];
  services.sshguard.enable = true;
}
