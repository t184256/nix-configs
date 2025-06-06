{ pkgs, lib, config, ... }:

let
  sys-connector = "HDMI-A-1";  # TODO: varies by host
  gnome-connector = "HDMI-1";  # TODO: varies by host
  autores-script = pkgs.writeScript "autores-script" ''
    #!/usr/bin/env bash
    set -Eeuo pipefail; shopt -s inherit_errexit

    mode="''${SUNSHINE_CLIENT_WIDTH}x''${SUNSHINE_CLIENT_HEIGHT}"
    hw_mode='keep'; scale='keep'
    case "$mode" in
            3840x2160) hw_mode='3840x2160@60.000'; scale=2;;  # generic 4K
            2960x1848) hw_mode='2960x1848@59.980'; scale=2;;  # 14" Tab S8 Ultra
            2560x1600) hw_mode='2560x1600@59.972'; scale=2;;  # 10" OneNetbook 4
            2208x1768) hw_mode='2208x1768@59.955'; scale=2;;  # 8" Samsung Fold2
            2048x1536) hw_mode='2048x1536@60.017'; scale=2;;  # 8" Tab S2 8.0
            1920x1080) hw_mode='1920x1080@60.000';;  # generic FullHD
    esac

    args=()
    [[ "$hw_mode" != 'keep' ]] && args+=(-m "$hw_mode")
    [[ "$scale" != 'keep' ]] && args+=(--scale "$scale")
    [[ -n "''${args[*]}" ]] && \
      gnome-randr modify "''${args[@]}" '${gnome-connector}'
  '';
  fixer-script = pkgs.writers.writePython3
    "sunshine-fixer"
    { libraries = [ pkgs.python3Packages.python-uinput ]; }
    ''
      from pathlib import Path
      import time
      import subprocess
      import sys

      import uinput


      def state(output='card1-${sys-connector}'):
          t = Path(f'/sys/class/drm/{output}/dpms').read_text().strip()
          return t == 'On'


      mouse = uinput.Device([uinput.REL_X, uinput.REL_Y, uinput.BTN_LEFT],
                            name='sunshine-fixer')
      f = subprocess.Popen(['journalctl', '-f', '-t', 'sunshine'],
                           stdout=subprocess.PIPE, encoding='utf-8')
      while True:
          line = f.stdout.readline()
          if 'Info: Trying encoder [vaapi]' in line:  # requires info level
              if state():
                  print('no wiggling required', file=sys.stderr)
              else:
                  mouse.emit(uinput.REL_X, -1)
                  time.sleep(.05)
                  mouse.emit(uinput.REL_X, 1)
                  time.sleep(.05)
                  print(f'wiggled, new output state={state()}', file=sys.stderr)
    '';
  edid-custom = pkgs.runCommand "edid-custom" {} ''
    mkdir -p "$out/lib/firmware/edid"
    cat ${../../misc/custom.edid} > "$out/lib/firmware/edid/custom.edid"
  '';
in
{
  # TODO: more declarative pairing / secret management?
  services.sunshine = {
    enable = true;
    capSysAdmin = true;
    openFirewall = true;
    settings = {
      sunshine_name = lib.mkDefault config.networking.hostName;
      origin_web_ui_allowed = "pc";  # pc / lan / wan
      capture = "kms";
      lan_encryption_mode = 2;
      wan_encryption_mode = 2;
      encoder = "quicksync";
      min_log_level = "info";  # fixer requires it
      # qsv_preset = "medium";
      # ping_timeout = 10000;
      # adapter_name = "/dev/dri/renderD128";
      # min_threads = 2;
      # hevc_mode = 0;
      # av1_mode = 0;
      # channels = 1;
      # global_prep_cmd = [ "" ];
      # output_name = "";
      # min_log_level = "verbose";
    };
    applications.env = {
        PATH = "$(PATH):${pkgs.bash}/bin:${pkgs.gnome-randr}/bin";
    };
    applications.apps = [
      {
        name = "Automatic resolution desktop";
        prep-cmd = [ { do = autores-script; } ];
        exit-timeout = 1;
        auto-detach = "true";
      }
      { name = "Desktop"; exit-timeout = 1; auto-detach = "true"; }
    ];
  };

  systemd.services.sunshine-fixer = {
    description = "Wiggler that wakes up the display when sunshine struggles";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${fixer-script}";
      Restart = "on-failure";
    };
  };

  environment.persistence."/mnt/persist".users.monk.directories = [
    ".config/sunshine"
  ];

  # TODO: applying handmade custom edid
  hardware.display = {
    edid.enable = true;
    edid.packages = [ edid-custom ];
    outputs."${sys-connector}".edid = "custom.edid";
  };
}
