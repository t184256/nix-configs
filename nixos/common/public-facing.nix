let
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJdiUFI5EQP2AT1/UjvR+OvJacPB4nvj7yWEpjmNnnFK monk@cola"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH1qSr+UBPFaonyFpWe0kUqZLNvukg7PsrwmpqOAEZ9v monk@lychee"
  ];
in
{
  services.openssh.enable = true;
  services.sshguard.enable = true;

  # mosh
  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];

  # syncthing
  networking.firewall.allowedTCPPorts = [ 22000 ];
  networking.firewall.allowedUDPPorts = [ 22000 21027 ];

  users.users.root.openssh.authorizedKeys.keys = sshKeys;
  users.users.monk.openssh.authorizedKeys.keys = sshKeys;
}
