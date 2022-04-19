{ ... }:

# TODO: consider integrated monitoring
{
  mailserver = {
    enable = true;
    fqdn = "unboiled.info";
    domains = [ "unboiled.info" ];
    messageSizeLimit = 209715200;  # 200 MB
    certificateScheme = 3;  # automatically via Let's Encrypt
    enableManageSieve = true;
    localDnsResolver = false;  # I have a DNS server on the same host
    loginAccounts = {
        "monk@unboiled.info" = {
            hashedPasswordFile = "/mnt/persist/secrets/mail/monk";
            aliases = [
                "abuse@unboiled.info"
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
            ];
        };
    };
  };

  environment.persistence."/mnt/persist".directories = [
    "/var/dkim"
    "/var/lib/rspamd"
    "/var/vmail"
  ];
}