{ config, pkgs, ... }:

{
  imports = [ ./postgresql.nix ];
  services.lemmy = {
    enable = true;
    settings.hostname = "lemmy.unboiled.info";
    database.createLocally = true;
    settings.port = 8536;
    ui.port = 1284;  # non-default ui port
  };
  services.nginx = {
    virtualHosts."lemmy.unboiled.info" = {
      enableACME = true;
      forceSSL = true;
      #locations."/".proxyPass = "http://127.0.0.1:1284";
      locations."/".extraConfig = ''
        set $proxpass "http://127.0.0.1:1284";
        if ($request_method = POST) {
          set $proxpass "http://127.0.0.1:8536";
        }
        if ($http_accept = "application/activity+json") {
          set $proxpass "http://127.0.0.1:8536";
        }
        if ($http_accept = "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"") {
          set $proxpass "http://127.0.0.1:8536";
        }
        proxy_pass $proxpass;
      '';
      extraConfig = ''
        location ~ ^/(api|pictrs|feeds|nodeinfo|.well-known) {
          proxy_pass "http://127.0.0.1:8536";
        }
      '';
    };
  };
  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/var/lib/private/pict-rs";
      user = "pict-rs"; group = "pict-rs";
    }
  ];
}
