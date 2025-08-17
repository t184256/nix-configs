{ config, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [ 5222 5281 5269 7777 ];  # not 5347
  networking.firewall.allowedUDPPorts = [ 7777 ];
  services.prosody = {
    enable = true;

    admins = [ "monk@unboiled.info" ];
    allowRegistration = false;  # it's even false by default

    muc = [ { domain = "conference.xmpp.unboiled.info"; } ];
    httpFileShare.domain = "upload.xmpp.unboiled.info";

    modules = {
      mam = true;
      proxy65 = true;
      csi = true;                 # omitting non-urgent data on sleeping devices
      smacks = true;              # session resumption
      watchregistrations = true;  # just in case
    };

    extraModules = [
      #"bookmarks2"
      #"checkcerts"         # for reminding about expirind certificates
      "csi_battery_saver"  # aggressive csi implementation
      "idlecompat"         # for deprioritizing 'last activity' for csi
      "mam_archive"        # for MAM and XEP-0136: Message Archiving interplay?
      "offline_email"      # for relaying messages to email if offline
      "watchuntrusted"     # for reporting s2s encryption-related failures
    ];
    package = pkgs.prosody.override {
      withCommunityModules = config.services.prosody.extraModules;
    };

    extraConfig = ''
      authentication = "internal_hashed"
      certificates = "/var/lib/acme/unboiled.info-prosody"
      storage = "sql"

      proxy65_ports = { 7777 }

      default_archive_policy = true
      max_archive_query_results = 100
      archive_expires_after = "never"

      queue_offline_emails = 90

      log = {
        warn = "/var/lib/prosody/prosody.log";
        warn = "*syslog";
      }

      Component "irc.unboiled.info"
          component_secret = "notasecret"
    '';

    s2sSecureAuth = true;

    ssl.cert = "/var/lib/acme/unboiled.info-prosody/fullchain.pem";
    ssl.key = "/var/lib/acme/unboiled.info-prosody/key.pem";
    virtualHosts."unboiled.info" = {
      enabled = true;
      domain = "unboiled.info";
      ssl.cert = "/var/lib/acme/unboiled.info-prosody/fullchain.pem";
      ssl.key = "/var/lib/acme/unboiled.info-prosody/key.pem";
      ssl.extraOptions.cafile = "/etc/ssl/certs/ca-bundle.crt";
    };
  };
  #services.biboumi = {
  #  enable = true;
  #  settings = {
  #    hostname = "irc.unboiled.info";
  #    password = "notasecret";
  #    persistent_by_default = true;
  #  };
  #};
  systemd.services.prosody.after = [ "network-online.target" ];
  systemd.services.prosody.wants = [ "network-online.target" ];
  systemd.services.prosody.postStart = ''
    #!${pkgs.bash}/bin/bash
    while sleep .5; do (: </dev/tcp/localhost/5347) 2>/dev/null && break; done
  '';
  #systemd.services.biboumi.requires = [ "prosody.service" ];
  #systemd.services.biboumi.after = [ "prosody.service" ];
  security.acme.certs = {
    "unboiled.info-prosody" = {
      domain = "unboiled.info";
      group = "prosody";
      webroot = "/var/lib/acme/acme-challenge";
      extraDomainNames = [
        "conference.xmpp.unboiled.info"
        "upload.xmpp.unboiled.info"
      ];
      postRun = "systemctl restart prosody";
    };
  };
  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/var/lib/prosody";
      user = "prosody"; group = "prosody";
    }
    #{
    #  directory = "/var/lib/private/biboumi";
    #  user = "biboumi"; group = "biboumi";
    #}
  ];
}
