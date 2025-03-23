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
  services.pict-rs.package = pkgs.pict-rs;  # TODO: remove on migration
  # https://join-lemmy.org/docs/administration/from_scratch.html?
  services.nginx = {
    virtualHosts."lemmy.unboiled.info" = {
      enableACME = true;
      forceSSL = true;
      # needed for recommendedProxySettings to take an effect
      #locations."/".proxyPass = "http://127.0.0.1:1284";
      # but cannot be specified dynamically,
      # therefore I have to be explicit belo
      locations."/".extraConfig = ''
        set $proxpass "http://127.0.0.1:1284";
        if ($http_accept ~ "^application/.*$") {
          set $proxpass "http://127.0.0.1:8536";
        }
        if ($request_method = POST) {
          set $proxpass "http://127.0.0.1:8536";
        }
        proxy_pass $proxpass;
        rewrite ^(.+)/+$ $1 permanent;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Server $host;
      '';
      extraConfig = ''
        location ~ ^/(api|pictrs|feeds|nodeinfo|.well-known) {
          proxy_pass "http://127.0.0.1:8536";
          limit_req zone=lemmy_ratelimit burst=30 nodelay;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Server $host;
        }
        client_max_body_size 20M;
        add_header Strict-Transport-Security "max-age=63072000";
        add_header Referrer-Policy "same-origin";
        add_header X-Content-Type-Options "nosniff";
        add_header X-Frame-Options "DENY";
        add_header X-XSS-Protection "1; mode=block";
      '';
    };
    appendHttpConfig = ''
      limit_req_zone $binary_remote_addr zone=lemmy_ratelimit:1m rate=2r/s;
    '';  # TODO: 1r/s
  };
  environment.persistence."/mnt/persist".directories = [
    { directory = "/var/lib/private"; mode = "0700"; }
    {
      directory = "/var/lib/private/pict-rs";
      user = "pict-rs"; group = "pict-rs";
    }
  ];
}
