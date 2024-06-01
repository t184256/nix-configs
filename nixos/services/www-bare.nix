_:

{
  services.nginx = {
    enable = true;
    virtualHosts."unboiled.info" = {
      enableACME = true;
      forceSSL = true;
      locations."/".extraConfig = ''
          location ~ .* {
            return 301 https://monk.unboiled.info;
          }
      '';
    };
  };
  security.acme.certs."unboiled.info".email = "monk@unboiled.info";
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
