{ pkgs, ... }:

{
  services.power-profiles-daemon.enable = true;
  systemd.services.set-perf-profile = {
    after = [ "power-profiles-daemon.service" ];
    serviceConfig.Type = "oneshot";
    path = [ pkgs.power-profiles-daemon ];
    script = "powerprofilesctl set performance";
  };
}
