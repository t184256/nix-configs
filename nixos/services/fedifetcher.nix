{ pkgs, ... }:

let
  configPath = "/mnt/persist/secrets/fedifetcher/mastodon.json";
  stateRoot = "/var/lib/fedifetcher";
in
{
  users = {
    users.fedifetcher.home = stateRoot;
    users.fedifetcher.createHome = true;
    users.fedifetcher.isSystemUser = true;
    users.fedifetcher.group = "fedifetcher";
    groups.fedifetcher = {};
  };
  systemd = {
    timers.fedifetcher = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "*:03/48";
      partOf = [ "fedifetcher.service" ];
    };
    services.fedifetcher = {
      unitConfig.ConditionPathExists = configPath;
      serviceConfig.WorkingDirectory = stateRoot;
      serviceConfig.Type = "oneshot";
      serviceConfig.ExecStart =
        "${pkgs.fedifetcher}/bin/fedifetcher"
        + " --config ${configPath}"
        + " --state-dir ${stateRoot}";
      serviceConfig.User = "fedifetcher";
      serviceConfig.Group = "fedifetcher";
    };
  };
  environment.persistence."/mnt/persist".directories = [
    { directory = stateRoot; user = "fedifetcher"; group = "fedifetcher"; }
  ];
}
