{ ... }:

{
  services.podcastify = {
    enable = true;
    address = "127.0.0.1";
    port = 9696;
    configFile = "/etc/podcastify/config.yml";
  };
  services.nginx = {
    enable = true;
    virtualHosts."podcastify.unboiled.info" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:9696";
      extraConfig = ''
        proxy_read_timeout 180;
      '';
    };
  };
  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/etc/podcastify";
      mode = "550";
      user = "podcastify";
      group = "podcastify";
    }
  ];
}
