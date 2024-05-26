{ ... }:

{
  services.nginx = {
    enable = true;
    virtualHosts."monk.unboiled.info" = {
      enableACME = true;
      forceSSL = true;
      locations = {
        "/" = {
          root = "/srv/monk";
          tryFiles = "$uri @fallback";
          extraConfig = ''
            location /pub/key/pgp {
              add_header Content-Type text/plain;
            }
          '';
        };
        "@fallback".root = "/srv/monk/www";
      };
    };
  };
  security.acme.certs."monk.unboiled.info".email = "monk@unboiled.info";
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
