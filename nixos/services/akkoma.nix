{ config, pkgs, ... }:

{
  imports = [ ./postgresql.nix ];
  services.akkoma = {
     enable = true;
     initDb.enable = true;
     extraStatic."static/terms-of-service.html" =
       pkgs.writeText "terms-of-service.html" "No service, no rules.";
     extraStatic."favicon.png" = pkgs.fetchurl {
       url = "https://avatars.githubusercontent.com/u/5991987?v=4";
       sha256 = "1d1mshxgjns4qz35cpnhk1acjv6rds4gkhay6a20zd9zxscfd393";
     };
     extraStatic."emoji/custom/nixos.png" = pkgs.fetchurl {
       url = "https://cdn.fosstodon.org/custom_emojis/images/000/062/778/original/48d6a1983312ea5a.png";
       sha256 = "f97dd2f1d56a11c33c841f8eab1c1a36f47aad4252eed967f04e28ac26fe30e2";
     };
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
