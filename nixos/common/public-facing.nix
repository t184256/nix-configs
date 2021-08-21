let
  sshKeys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC6sAEM9vo0ocfnyAlhmG+clkdNIH0J8NLzZIbnHOAfTnnLzUeWOT14JR7Q//kTCdorjbX0dWD/+TRIwFHdXtLQngqaqSc77+1nRkx/4R5tbzJrd/FYA/4zk+sPpDHDidcntJQ5chduyiuESn3L0H0OT0muck0g92BAkGATaswNWLLnu/TC1486krkG0aQxDDFIYggzJR6v/saCrTGtMVMOhoMcWKGGQpFCYznB+3scYucTc4o9CGY/hpYeukZZ72xmaYWZqIQnCm7pfLyJWNkw70EO1r1EBStuhYWEUqgTfgfu6KQHRpRiMPWf0Oss44DQR5fIkY/VTCBeIWOdX2TC6qVfgMKASfIyYzPMorDtAcrXhRb4aEZqh9p7AjLs8izfFR8/GSdoxIda3b+cfFPZ5dk05oOS3wkMQOy5ZeGv/jp8WZds7MC9+xNMhdZ94hRU6dN7S6yq+btrgPLWXk96yl4VZkwRz9fxk7PqZZ8riz9VAfKE2llkC5pEXx09B0oUxu9DXzGZI9acOG3YAtXlezhCaS6AcvQZbQ7CXKHd/sGXrf9T+sqYX9k4FnLm7eoWHH0rEMC3QVPGbIs4rGZbjBBybVrgSL8ShFpmhw9F1PyD6ug2t41NBIbZr9e2eFaVO2LaPpZPoKFGZoILrtB/vW32BmQV20Ibr7cK2dPcbQ=="
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
