{ config, pkgs, ... }:

let
  dyndns = pkgs.writeShellScript "dyndns" ''
    set -ueo pipefail
    hostname=$1
    if [[ -e /run/credentials/dyndns.service/token ]]; then  # 2024
      token="$(cat /run/credentials/dyndns.service/token)"
    elif [[ -e /mnt/secrets/dynv6 ]]; then
      token="$(cat /mnt/secrets/dynv6)"
    else
      token="$(cat /mnt/persist/secrets/dynv6)"
    fi

    curl="${pkgs.curl}/bin/curl -fsS --connect-timeout 5 --max-time 10"
    url4="https://ipv4.dynv6.com/api/update?token=$token"
    url6="https://ipv6.dynv6.com/api/update?token=$token"
    urlA="https://dynv6.com/api/update?token=$token"

    $curl -4 "$url4&zone=$hostname.dyn4.unboiled.info&ipv4=auto" || true
    $curl -6 "$url6&zone=$hostname.dyn6.unboiled.info&ipv6=auto" || true
    $curl -4 "$url4&zone=$hostname.dyn.unboiled.info&ipv4=auto" || true
    $curl -6 "$url6&zone=$hostname.dyn.unboiled.info&ipv6=auto"
  '';
in
{
  systemd = {
    timers.dyndns = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "*:43/15";
      partOf = [ "dyndns.service" ];
    };
    services.dyndns = {
      #unitConfig.ConditionPathExists = "/mnt/secrets/dynv6";  # 2024
      serviceConfig.Type = "oneshot";
      serviceConfig.ExecStart = "${dyndns} ${config.networking.hostName}";
      # LoadCredential = [ "token:/mnt/secrets/dyndns" ];  # TODO: 2024
    };
  };
}
