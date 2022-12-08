{ ... }:

{
  services.diffoscope-server = {
    enable = true;
    address = "127.0.0.1";
    port = 9999;
  };
  services.nginx = {
    enable = true;
    virtualHosts."diff.unboiled.info" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:9999";
    };
  };
}
