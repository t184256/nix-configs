{ ... }:

# TODO: consider integrated monitoring
{
  mailserver = {
    enable = true;
    stateVersion = 3;
    fqdn = "unboiled.info";
    domains = [ "unboiled.info" ];
    messageSizeLimit = 209715200;  # 200 MB
    certificateScheme = "acme-nginx";
    enableManageSieve = true;
    localDnsResolver = false;  # I have a DNS server on the same host
    loginAccounts = {
        "monk@unboiled.info" = {
            hashedPasswordFile = "/mnt/persist/secrets/mail/monk";
            aliases = [
                "abuse@unboiled.info"
                "admin@unboiled.info"
                "info@unboiled.info"
                "root@unboiled.info"
                "hostmaster@unboiled.info"
                "postmaster@unboiled.info"
                "webmaster@unboiled.info"
                "alexander.sosedkin@unboiled.info"
                "sosedkin.alexander@unboiled.info"
                "aleksander.sosedkin@unboiled.info"
                "sosedkin.aleksander@unboiled.info"
                "alexandr.sosedkin@unboiled.info"
                "sosedkin.alexandr@unboiled.info"
                "aleksandr.sosedkin@unboiled.info"
                "sosedkin.aleksandr@unboiled.info"
                "monk+nv@unboiled.info"
                "monk+spotify-cz@unboiled.info"
                "monk+paypal-cz@unboiled.info"
                "monk+steampartner@unboiled.info"
                "monk.cz@unboiled.info"
                "nix-on-droid@unboiled.info"
            ];
        };
        "shared@unboiled.info" = {
            hashedPasswordFile = "/mnt/persist/secrets/mail/shared";
            aliases = [
                "blackhole@unboiled.info"
            ];
        };
    };
  };

  # extra non-standard SMTP ports
  networking.firewall.allowedTCPPorts = [ 14465 15587 ];
  services.xinetd.enable = true;
  services.xinetd.services = [
    {
      name = "smtp-alt"; unlisted = true; port = 14465;
      server = "/usr/bin/env";  # must be something executable
      extraConfig = "redirect = localhost 465";
    }
    {
      name = "smtps-alt"; unlisted = true; port = 15587;
      server = "/usr/bin/env";  # must be something executable
      extraConfig = "redirect = localhost 587";
    }
  ];

  environment.persistence."/mnt/persist".directories = [
    "/var/dkim"
    "/var/lib/rspamd"
    "/var/vmail"
  ];
}
