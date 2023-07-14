{ config, pkgs, ... }:

{
  imports = [ ./postgresql.nix ];
  services.akkoma = {
     enable = true;
     initDb.enable = true;
     config.":pleroma" = {
       "Pleroma.Web.Endpoint".url.host = "social.unboiled.info";
       ":instance" = {
         name = "social.unboiled.info";
         email = "admin@unboiled.info";
         description = "monk's single-user fediverse instance";
         registrations_open = false;
         account_approval_required = true;
         allow_relay = true;
     };
    };
  };
  services.nginx = {
    virtualHosts."social.unboiled.info" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://unix:/run/akkoma/socket";
    };
  };
  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/var/lib/secrets/akkoma";
      user = "akkoma"; group = "akkoma";
    }
    {
      directory = "/var/lib/akkoma";
      user = "akkoma"; group = "akkoma";
    }
  ];
}
