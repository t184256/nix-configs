{ pkgs, lib, config, ... }:

let
  cfg = config.services.apollo;

  edid-custom = pkgs.runCommand "edid-custom" {} ''
    mkdir -p "$out/lib/firmware/edid"
    cat ${../../misc/custom.edid} > "$out/lib/firmware/edid/custom.edid"
  '';

  # gdctl is the GNOME Display Control utility shipped with mutter,
  # not in PATH by default
  gdctl = "${pkgs.mutter}/bin/gdctl";

  # kernel-level DRM connector name for a GNOME/xrandr output name.
  # DP/eDP/DVI names are identical, HDMI-N maps to HDMI-A-N.
  # Already kernel-level names pass through unchanged.
  kernel-output = output:
    if lib.match "HDMI-[0-9]+" output != null
    then "HDMI-A-${lib.removePrefix "HDMI-" output}"
    else output;

  gdctl-set-args = monitor:
    "set --logical-monitor --primary --monitor ${monitor.output}${
      if monitor.force-mode == null then "" else " --mode ${monitor.force-mode}"
    }";

  apollo-do = pkgs.writeScript "apollo-do" (
    ''
      #!/usr/bin/env bash
      set -Eeuo pipefail; shopt -s inherit_errexit

    ''
    + lib.optionalString cfg.switch.mask-bluetooth ''
      # NixOS workaround for a broken sudo systemctl mask --runtime bluetooth
      sudo ln -sf /dev/null /run/systemd/transient/bluetooth.service
      sudo systemctl daemon-reload
      sudo systemctl stop bluetooth
    ''
    + ''
      ${gdctl} ${gdctl-set-args cfg.switch.streaming}
    ''
  );
  apollo-undo = pkgs.writeScript "apollo-undo" (
    ''
      #!/usr/bin/env bash
      set -Eeuo pipefail; shopt -s inherit_errexit

    ''
    + lib.optionalString cfg.switch.lock-session ''
      sudo loginctl lock-sessions
    ''
    + ''
      ${gdctl} ${gdctl-set-args cfg.switch.display}
    ''
    + lib.optionalString cfg.switch.mask-bluetooth ''
      # unmask and start bluetooth (inverse of the do, tolerating failures)
      sudo rm -f /run/systemd/transient/bluetooth.service || \
        echo "apollo-undo: unmask bluetooth failed (continuing)" >&2
      sudo systemctl daemon-reload || \
        echo "apollo-undo: daemon-reload failed (continuing)" >&2
      sudo systemctl start bluetooth || \
        echo "apollo-undo: start bluetooth failed (continuing)" >&2
    ''
  );

  desktop-app =
    if cfg.switch.enable then
      {
        name = "Desktop";
        exit-timeout = 1;
        auto-detach = "true";
        prep-cmd = [ { do = apollo-do; undo = apollo-undo; } ];
      }
    else
      {
        name = "Desktop";
        exit-timeout = 1;
        auto-detach = "true";
      };
in
{
  imports = [ ./sunshine-fixer.nix ];

  options = {
    services.apollo.enable = lib.mkEnableOption
      "Apollo (Sunshine fork) streaming service";
    services.apollo.switch = {
      enable = lib.mkEnableOption
        "Switch monitors and bluetooth around streaming sessions";
      streaming = lib.mkOption {
        type = lib.types.submodule {
          options = {
            output = lib.mkOption {
              type = lib.types.str;
              description = "GNOME output used while streaming, e.g. DP-5";
            };
            force-mode = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Streaming mode to force (3840x2160@60.000)";
            };
            custom-edid = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Apply the custom EDID to streaming.output";
            };
          };
        };
        default = { };
        description = "Streaming layout settings";
      };
      display = lib.mkOption {
        type = lib.types.submodule {
          options = {
            output = lib.mkOption {
              type = lib.types.str;
              description = "GNOME output used at the desk, e.g. HDMI-2";
            };
            force-mode = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Desktop mode to force (3840x2160@120.000)";
            };
          };
        };
        default = { };
        description = "Desk layout settings";
      };
      lock-session = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Lock the session when streaming ends";
      };
      mask-bluetooth = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Mask and stop bluetooth while streaming in";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "uhid" ];
    hardware.uinput.enable = true;
    # TODO: more declarative pairing / secret management?
    services.sunshine = {
      enable = true;
      package = pkgs.apollo;
      capSysAdmin = true;
      openFirewall = true;
      settings = {
        sunshine_name = lib.mkDefault config.networking.hostName;
        origin_web_ui_allowed = "pc";  # pc / lan / wan
        capture = "kms";
        lan_encryption_mode = 2;
        wan_encryption_mode = 2;
        #encoder = "quicksync";
        #min_log_level = "info";  # fixer requires it
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
      # The apps are generated here so that the streaming layout
      # switch can be wired in as a prep-cmd.
      applications.apps = lib.mkForce [ desktop-app ];
    };

    environment.persistence."/mnt/persist".users.monk.directories = [
      ".config/sunshine"
    ];
    environment.persistence."/mnt/persist".directories = [
      "/var/lib/gdm/seat0/config/sunshine"
    ];

    # TODO: applying handmade custom edid
    hardware.display = lib.mkIf cfg.switch.streaming.custom-edid {
      edid.enable = true;
      edid.packages = [ edid-custom ];
      outputs."${kernel-output cfg.switch.streaming.output}".edid
        = "custom.edid";
    };

    assertions = lib.optional cfg.switch.enable {
      assertion =
        cfg.switch.streaming.output != ""
        && cfg.switch.display.output != "";
      message = "services.apollo.switch: outputs required when enable = true";
    } ++ lib.optional cfg.switch.streaming.custom-edid {
      assertion = cfg.switch.streaming.output != "";
      message = "services.apollo.switch.streaming.custom-edid: output required";
    };
  };
}
