{ config, lib, ... }:

{
  services.nginx = {
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;
    recommendedProxySettings = true;
  };
  networking.firewall.allowedTCPPorts =
    lib.mkIf config.services.nginx.enable [ 80 443 ];
}
