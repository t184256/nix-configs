{ config, ... }:

let
  theGateway = "duckweed";
  isTheGateway = config.networking.hostName == theGateway;
in
{
  services.nginx = {
    virtualHosts."ipfs.unboiled.info" = {
      enableACME = isTheGateway;
      forceSSL = isTheGateway;
      locations."/".proxyPass = "http://127.0.0.1:4004";
      extraConfig = ''
        gzip off;
        gzip_proxied off;
        proxy_cache off;
        proxy_buffering off;
      '';
    };
  };
  services.kubo = {
    settings.Gateway = {
      #DeserializedResponses = false;
      NoDNSLink = false;
    };
  };
}
