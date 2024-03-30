let
  sshKeys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDU0npnGICaFEfRyb7FN1RhgxHlxF9Qr9wY3VX1Z+tP4WjL9PDk2Tk7xibfMBkXSYIeXzBSNBjHXKmU3i0PcZ7iJuNqOawYAB99Fc8Ti6d/eI0TSAp4beASNbNwPq1a27DN+4hxwS4r2nm8yBIjMZYdLZDorLm/8+HRxYb9GeprfEb90MOO0MKuPIJ8c6xwYqnqd7WB0AOSZl8JzA1h5sE1nsYbjxNM+bdkkysuQS7FJgF5Z2EoQeZn86PxpvdIRx6bkBta9e2si2mTRfgWLjwPlkHKLO+CaLyQMNOzN3AqlcABrNsMaq6s+N2U5U6KvSOJTAyo+Pq7+fjhHsCua4cUIb8X4+YuTDLAqRAiL5FD/M5EWbFWhRPQOejI0oAWJwSHveOdxojRyJPUXNqrzhzCxqnd57JuNlI6mlF60U0pOLsyHxvF7SVJXAfH7kh37Dh0x9RyJMlGE50YKXe/sNcmPYcJjvDSfKQTEPaFCMXUWvpw/uxCY/D+ww4ZE5RSVDJEo3Yb0NguzD58ym/VJYR23yKm6GdBMDhLqXH2LaU14AFygnZ2qKLGo8Jfj3IFah37iKuGrSknrngmCeNOtp7/X9uXt6MSjNMvwuxB8VthO0LWEBWNfGq96COtQYVFcBkmVl2Y8jVleesOC8jZkZbaR1ZAkTOrgJQUDmp3BlPWKw=="
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
