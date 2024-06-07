{ config, pkgs, ... }:

{
  imports = [ ./postgresql.nix ];
  services.akkoma = {
    enable = true;
    initDb.enable = true;
    extraStatic = {
      "static/terms-of-service.html" =
        pkgs.writeText "terms-of-service.html" "No service, no rules.";
      "favicon.png" = pkgs.fetchurl {
        url = "https://avatars.githubusercontent.com/u/5991987?v=4";
        sha256 = "1d1mshxgjns4qz35cpnhk1acjv6rds4gkhay6a20zd9zxscfd393";
      };
      "emoji/custom/nixos.png" = pkgs.fetchurl {
        url = "https://cdn.fosstodon.org/custom_emojis/images/000/062/778/original/48d6a1983312ea5a.png";
        sha256 = "1qihzqkaqa2fy1kxkvjj8anpmx1n38fap3hzhhyc64baspqx4zgr";
      };
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
        upload_limit = 41943040;  # 40 MB
      };
      ":pleroma" = {
        Oban.queues = { federator_incoming = 10; federator_outgoing = 10; };
        retries = { federator_incoming = 1; federator_outgoing = 1; };
      };
      "Pleroma.Repo" = {
        # copied over
        adapter = "Ecto.Adapters.Postgres";
        database = "akkoma";
        socket_dir = "/run/postgresql";
        username = "akkoma";
        # one I care about
        parameters.plan_cache_mode = "force_custom_plan";
      };
    };
  };
  services.nginx = {
    clientMaxBodySize = "40M";
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
