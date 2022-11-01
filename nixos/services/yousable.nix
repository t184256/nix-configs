{ ... }:

{
  services.yousable = {
    enable = true;
    address = "127.0.0.1";
    port = 9696;
    configFile = "/etc/yousable/config.yaml";
  };
  services.nginx = {
    enable = true;
    virtualHosts."yousable.unboiled.info" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:9696";
      extraConfig = ''
        gzip off;
        gzip_proxied off;
        proxy_cache off;
        proxy_buffering off;
      '';
      locations."/out".root = "/mnt/persist/cache/yousable";
      locations."/out".extraConfig = ''
        autoindex off;
        internal;
      '';
    };
  };
  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/etc/yousable";
      mode = "550";
      user = "yousable";
      group = "yousable";
    }
  ];
  fileSystems."/mnt/persist/cache/yousable/live" = {
    device = "/mnt/persist//home/monk/.sync/livestreams";
    options = [ "bind" ];
  };
}
