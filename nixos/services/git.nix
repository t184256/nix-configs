{ config, ... }:

{
  services.gitea = {
    enable = true;
    appName = "monk's private gitea";
    user = "git";  # I like my repo urls short
    database.user = "git";  # must match
    settings = {
      server.HTTP_ADDRESS = "127.0.0.1";
      server.HTTP_PORT = 3000;
      server.DOMAIN = "git.unboiled.info";
      server.ROOT_URL = "https://git.unboiled.info";
      session.DISABLE_REGISTRATION = true;  # 1st user becomes an admin.
      session.COOKIE_SECURE = true;
      service.REQUIRE_SIGNIN_VIEW = true;
    };
    dump.enable = true;
  };
  users.extraUsers.git = {
    description = "Gitea Service";
    home = config.services.gitea.stateDir;
    createHome = true;
    useDefaultShell = true;
    isSystemUser = true;
    group = "gitea";
  };
  services.nginx = {
    virtualHosts."git.unboiled.info" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:3000";
    };
  };
  systemd = {
    timers.gitea-dump-cleanup = {
      wantedBy = [ "timers.target" ];
      partOf = [ "gitea-dump-cleanup.service" ];
      timerConfig.OnCalendar = "daily";
    };
    services.gitea-dump-cleanup = {
      serviceConfig.Type = "oneshot";
      script = ''
        set -uexo pipefail
        find /var/lib/gitea/dump -type f | head -n-2
        find /var/lib/gitea/dump -type f | head -n-2 | xargs rm
      '';
    };
  };
  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/var/lib/gitea";
      user = "git"; group = "gitea";
    }
  ];
}
