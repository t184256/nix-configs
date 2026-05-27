{ pkgs, ... }:

let
  core_clock_min = 300;
  core_clock_max = 1500;  # can easily go up to 1700,
                          # but 1500 is enough for inference, and it's ~230W
  asus_clock_offset = 200;
  # 1695/837mV is baseline, 240 1695/743mV still worked
  msi_clock_offset = 200;
  # 1695/868mV is baseline, 260 1695/756mV still worked

  # offt ASUS MHz/mV  MSI MHz/mV
  #    0  1500/762mV  1500/781mV  ok 7.2s  1024tok  primes=25/25
  #   20  1500/756mV  1500/775mV  ok 6.6s  1024tok  primes=25/25
  #   40  1500/750mV  1500/768mV  ok 6.5s  1024tok  primes=25/25
  #   60  1500/737mV  1500/756mV  ok 6.7s  1024tok  primes=25/25
  #   80  1500/731mV  1500/750mV  ok 6.1s  1024tok  primes=25/25
  #  100  1500/725mV  1500/750mV  ok 7.1s  1024tok  primes=25/25
  #  120  1500/725mV  1500/737mV  ok 7.0s  1024tok  primes=25/25
  #  140  1500/725mV  1500/731mV  ok 6.1s  1024tok  primes=25/25
  #  160  1500/725mV  1500/725mV  ok 6.7s  1024tok  primes=25/25
  #  180  1500/725mV  1500/718mV  ok 6.7s  1024tok  primes=25/25
  #  200 *1500/725mV**1500/712mV* ok 7.3s  1024tok  primes=25/25
  #  220  1500/725mV  1500/712mV  ok 6.8s  1024tok  primes=25/25
  #  240  1500/725mV  1500/712mV  ok 6.7s  1024tok  primes=25/25
  #  260  1500/725mV  1500/712mV  FAIL: HTTP Error 500

  # offt  ASUS MHz/mV  MSI MHz/mV
  #    0  1695/843mV  1695/875mV  ok 6.3s  1024tok  primes=25/25
  #   20  1695/837mV  1695/862mV  ok 6.4s  1024tok  primes=25/25
  #   40  1695/825mV  1695/856mV  ok 6.2s  1024tok  primes=25/25
  #   60  1695/812mV  1695/837mV  ok 6.2s  1024tok  primes=25/25
  #   80  1695/806mV  1695/831mV  ok 6.4s  1024tok  primes=25/25
  #  100  1695/800mV  1695/825mV  ok 6.5s  1024tok  primes=25/25
  #  120  1695/787mV  1695/812mV  ok 6.7s  1024tok  primes=25/25
  #  140  1695/781mV  1695/806mV  ok 6.6s  1024tok  primes=25/25
  #  160  1695/775mV  1695/800mV  ok 6.1s  1024tok  primes=25/25
  #  180  1695/768mV  1695/787mV  ok 6.5s  1024tok  primes=25/25
  #  200 *1695/762mV**1695/781mV* ok 6.3s  1024tok  primes=25/25
  #  220  1695/756mV  1695/775mV  ok 6.6s  1024tok  primes=25/25
  #  240  1695/743mV  1695/762mV  ok 6.4s  1024tok  primes=25/25
  #  260  1695/737mV  1695/756mV  FAIL: HTTP Error 500
in

{
  hardware.nvidia.nvidiaPersistenced = true;

  services.lact.enable = true;

  # services.lact.settings serializes attrset keys as YAML strings,
  # but curve keys must be i32; write config directly instead.
  environment.etc."lact/config.yaml" = {
    mode = "0644";
    text = ''
      version: 5
      daemon:
        log_level: info
        admin_group: wheel
        disable_nvapi: false
      apply_settings_timer: 5
      gpus:
        "10DE:2204-1043:87AF-0000:11:00.0":  # ASUS
          power_cap: 250.0
          min_core_clock: ${toString core_clock_min}
          max_core_clock: ${toString core_clock_max}
          mem_clock_offsets:
            0: 0  # keep constant at 9501 MHz, do not overclock
          fan_control_enabled: true
          fan_control_settings:
            mode: curve
            temperature_key: unused
            interval_ms: 500
            spindown_delay_ms: 10000
            change_threshold: 2
            auto_threshold: 48
            curve:
              50: 0.45  # awkwardly starts/stalls audibly with 0.3-0.4
              60: 0.6
              70: 1.0
        "10DE:2204-1462:3884-0000:01:00.0":  # MSI
          power_cap: 250.0
          min_core_clock: ${toString core_clock_min}
          max_core_clock: ${toString core_clock_max}
          mem_clock_offsets:
            0: 0  # keep constant at 9501 MHz, do not overclock
          fan_control_enabled: true
          fan_control_settings:
            mode: curve
            temperature_key: unused
            interval_ms: 500
            spindown_delay_ms: 10000
            change_threshold: 2
            auto_threshold: 38
            curve:
              50: 0.3
              60: 0.5
              70: 0.6
              80: 1.0
      profiles:
        under:
          gpus:
            "10DE:2204-1043:87AF-0000:11:00.0":  # ASUS
              power_cap: 250.0
              min_core_clock: ${toString core_clock_min}
              max_core_clock: ${toString core_clock_max}
              gpu_clock_offsets:
                0: ${toString asus_clock_offset}
              mem_clock_offsets:
                0: 0  # keep constant at 9501 MHz, do not overclock
              fan_control_enabled: true
              fan_control_settings:
                mode: curve
                temperature_key: junction
                interval_ms: 500
                change_threshold: 2
                auto_threshold: 48
                curve:
                  60: 0.45  # awkwardly starts/stalls audibly with 0.3-0.4
                  70: 0.7
                  80: 1.0
            "10DE:2204-1462:3884-0000:01:00.0":  # MSI
              power_cap: 250.0
              min_core_clock: ${toString core_clock_min}
              max_core_clock: ${toString core_clock_max}
              gpu_clock_offsets:
                0: ${toString msi_clock_offset}
              mem_clock_offsets:
                0: 0  # keep constant at 9501 MHz, do not overclock
              fan_control_enabled: true
              fan_control_settings:
                mode: curve
                temperature_key: junction
                interval_ms: 500
                spindown_delay_ms: 10000
                change_threshold: 2
                auto_threshold: 48
                curve:
                  60: 0.3
                  70: 0.5
                  80: 0.7
                  90: 1.0
    '';
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "lact-vf-table" ''
      exec ${pkgs.python3}/bin/python3 ${./lact-vf-table.py} \
        "10DE:2204-1043:87AF-0000:11:00.0" ASUS ${toString asus_clock_offset} \
        "10DE:2204-1462:3884-0000:01:00.0" MSI ${toString msi_clock_offset}
    '')
  ];
}
