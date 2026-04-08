{ pkgs, lib, ... }:

{
  services.tang = {
    enable = true;
    listenStream = [ "1449" ];
    ipAddressAllow = [ "any" ];
  };
  systemd.services."tangd@".serviceConfig = {
    ExecStart = lib.mkForce "${pkgs.tang}/libexec/tangd %d";
    StateDirectory = lib.mkForce "";
    LoadCredential = [
      "sig.jwk:/mnt/storage/secrets/tang/sig.jwk"
      "exc.jwk:/mnt/storage/secrets/tang/exc.jwk"
    ];
  };
  systemd.sockets.tangd = {
    requires = [ "mnt-storage.mount" ];
    after = [ "mnt-storage.mount" ];
    wantedBy = lib.mkForce [ "mnt-storage.target" ];
    partOf = [ "mnt-storage.target" ];
  };
  networking.firewall.allowedTCPPorts = [ 1449 ];
}
