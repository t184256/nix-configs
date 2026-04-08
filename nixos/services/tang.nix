{ pkgs, lib, ... }:

{
  services.tang = {
    enable = true;
    listenStream = [ "1449" ];
    ipAddressAllow = [ "any" ];
  };
  systemd.services."tangd@".serviceConfig = {
    ExecStart = lib.mkForce "${pkgs.tang}/libexec/tangd /mnt/storage/secrets/tang";
    DynamicUser = lib.mkForce false;
    PrivateUsers = lib.mkForce false;
    User = lib.mkForce "root";
    StateDirectory = lib.mkForce "";
  };
  systemd.sockets.tangd = {
    requires = [ "mnt-storage.mount" ];
    after = [ "mnt-storage.mount" ];
    wantedBy = lib.mkForce [ "mnt-storage.target" ];
    partOf = [ "mnt-storage.target" ];
  };
  networking.firewall.allowedTCPPorts = [ 1449 ];
}
