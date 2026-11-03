# Wakes up a sleeping display when sunshine starts encoding
# https://github.com/orgs/LizardByte/discussions/439#discussioncomment-11568754

{ pkgs, config, lib, ... }:

let
  cfg = config.services.sunshine-fixer;
  fixer-script = pkgs.writers.writePython3
    "sunshine-fixer"
    { libraries = [ pkgs.python3Packages.python-uinput ]; }
    ''
      from pathlib import Path
      import time
      import subprocess
      import sys

      import uinput


      def state(output='${cfg.output}'):
          t = Path(f'/sys/class/drm/{output}/dpms').read_text().strip()
          return t == 'On'


      mouse = uinput.Device([uinput.REL_X, uinput.REL_Y, uinput.BTN_LEFT],
                            name='sunshine-fixer')
      f = subprocess.Popen(['journalctl', '-f', '-t', '${cfg.journalTag}'],
                           stdout=subprocess.PIPE, encoding='utf-8')
      while True:
          line = f.stdout.readline()
          if '${cfg.logPattern}' in line:  # requires info level
              if state():
                  print('no wiggling required', file=sys.stderr)
              else:
                  mouse.emit(uinput.REL_X, -1)
                  time.sleep(.05)
                  mouse.emit(uinput.REL_X, 1)
                  time.sleep(.05)
                  print(f'wiggled, new output state={state()}', file=sys.stderr)
    '';
in
{
  options.services.sunshine-fixer = with lib.types; {
    enable = lib.mkEnableOption
      "Wiggles a virtual mouse to wake up the display for sunshine";
    output = lib.mkOption {
      type = str;
      description =
        "Name of the DRM output to watch for DPMS state, e.g. card1-HDMI-A-1.";
    };
    journalTag = lib.mkOption {
      type = str;
      default = "sunshine";
      description = "Journal tag of the streaming service to tail";
    };
    logPattern = lib.mkOption {
      type = str;
      default = "Trying encoder [";
      description = "Log line indicating that the encoder is starting";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.uinput.enable = true;
    # the trigger line is only logged at info level
    services.sunshine.settings.min_log_level = lib.mkDefault "info";

    systemd.services.sunshine-fixer = {
      description = "Wiggler that wakes up the display when sunshine struggles";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${fixer-script}";
        Restart = "on-failure";
      };
    };
  };
}
