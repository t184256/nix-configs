{ config, lib, ... }:

{
  services.nginx = {
    recommendedGzipSettings = true;
    recommendedZstdSettings = true;  # use zstd when it's fixed
    recommendedBrotliSettings = true;  # use zstd when it's fixed
    recommendedOptimisation = true;
    recommendedTlsSettings = true;
    recommendedProxySettings = true;
  };
  networking.firewall.allowedTCPPorts =
    lib.mkIf config.services.nginx.enable [ 80 443 ];
}
