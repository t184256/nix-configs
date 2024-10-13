{ pkgs, lib, config, ... }:

let
  connector = "HDMI-1";  # TODO: varies by host
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
            1920x1080) hw_mode='1920x1080@60.000'; scale=1;;  # generic FullHD
    esac

    args=()
    [[ "$hw_mode" != 'keep' ]] && args+=(-m "$hw_mode")
    [[ "$scale" != 'keep' ]] && args+=(--scale "$scale")
    [[ -n "''${args[*]}" ]] && gnome-randr modify "''${args[@]}" '${connector}'
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

  environment.persistence."/mnt/persist".users.monk.directories = [
    ".config/sunshine"
  ];

  # TODO: applying handmade custom edid
}
