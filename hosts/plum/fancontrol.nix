{ config, pkgs, ... }:

let
  # assumes SYS_FAN# on motherboard = pwm# in nct6687d driver
  exhaust = "3 4";    # top SYS_FAN1 (fan3), rear SYS_FAN2 (fan4)
  intake  = "6 7 8";  # bottom SYS_FAN4 (fan6), top front SYS_FAN5 (fan7),
                      # mid + bottom front SYS_FAN6 (fan8)
  tempMin = 70;
  tempMax = 100;
  delta = 20;  # intake PWM offset over exhaust for positive pressure

  script = pkgs.writeShellScript "gpu-fancontrol" ''
    set -euo pipefail
    temp_min=${toString tempMin}
    temp_max=${toString tempMax}
    delta=${toString delta}

    hwmon=
    for h in /sys/class/hwmon/hwmon*; do
      if [ "$(cat "$h/name" 2>/dev/null)" = "nct6687" ]; then
        hwmon=$h
        break
      fi
    done
    [ -n "$hwmon" ] || { echo "nct6687 hwmon not found" >&2; exit 1; }

    restore() {
      for n in ${exhaust} ${intake}; do
        echo 99 > "$hwmon/pwm''${n}_enable" 2>/dev/null || true
      done
    }
    trap restore EXIT
    for n in ${exhaust} ${intake}; do
      echo 1 > "$hwmon/pwm''${n}_enable"
    done

    while true; do
      temp=$(nvidia-smi \
        --query-gpu=temperature.gpu --format=csv,noheader \
        | sort -rn | head -1)

      if   (( temp <= temp_min )); then
        e=0 i=0
      elif (( temp >= temp_max )); then
        e=255 i=255
      else
        e=$(( (temp - temp_min) * 255 / (temp_max - temp_min) ))
        i=$(( e + delta )); (( i > 255 )) && i=255
      fi
      for n in ${exhaust}; do echo "$e" > "$hwmon/pwm$n"; done
      for n in ${intake};  do echo "$i" > "$hwmon/pwm$n"; done

      sleep 1
    done
  '';
in
{
  systemd.services.gpu-fancontrol = {
    description = "GPU temperature fan control";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    path = [ config.hardware.nvidia.package ];
    serviceConfig = {
      ExecStart = script;
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
