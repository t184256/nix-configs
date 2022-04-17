{ config, ... }:

{
  services.gitea = {
    enable = true;
    appName = "monk's private gitea";
    user = "git";  # I like my repo urls short
    database.user = "git";  # must match
    domain = "git.unboiled.info";
    rootUrl = "https://git.unboiled.info";
    httpAddress = "127.0.0.1";
    httpPort = 3000;
    cookieSecure = true;
    disableRegistration = true;  # The first registered user becomes an admin.
    settings.service.REQUIRE_SIGNIN_VIEW = true;
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
  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/var/lib/gitea";
      user = "git"; group = "gitea";
    }
  ];
}
