{ pkgs, ... }:

let
  configPath = "/mnt/persist/secrets/fedifetcher.json";
in
{
  users = {
    users.fedifetcher.home = "/var/lib/fedifetcher";
    users.fedifetcher.createHome = true;
    users.fedifetcher.isSystemUser = true;
    users.fedifetcher.group = "fedifetcher";
    groups.fedifetcher = {};
  };
  systemd = {
    timers.fedifetcher = {
      wantedBy = [ "timers.target" ];
      partOf = [ "fedifetcher.service" ];
      timerConfig.OnCalendar = "*:2/5";
    };
    services.fedifetcher.serviceConfig = {
      WorkingDirectory = "/var/lib/fedifetcher";
      ConditionFileExists = configPath;
      Type = "oneshot";
      ExecStart =
        "${pkgs.fedifetcher}/bin/fedifetcher"
        + " --config ${configPath}"
        + " --state-dir /var/lib/fedifetcher";
      User = "fedifetcher";
      Group = "fedifetcher";
    };
  };
  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/var/lib/fedifetcher";
      user = "fedifetcher"; group = "fedifetcher";
    }
  ];
}
