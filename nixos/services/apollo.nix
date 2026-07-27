{ pkgs, lib, config, ... }:

let
  sys-connector = "HDMI-A-1";  # TODO: varies by host
  #gnome-connector = "HDMI-1";  # TODO: varies by host
  edid-custom = pkgs.runCommand "edid-custom" {} ''
    mkdir -p "$out/lib/firmware/edid"
    cat ${../../misc/custom.edid} > "$out/lib/firmware/edid/custom.edid"
  '';
in
{
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
    applications.apps = [
      { name = "Desktop"; exit-timeout = 1; auto-detach = "true"; }
    ];
  };

  environment.persistence."/mnt/persist".users.monk.directories = [
    ".config/sunshine"
  ];
  environment.persistence."/mnt/persist".directories = [
    "/var/lib/gdm/seat0/config/sunshine"
  ];

  # TODO: applying handmade custom edid
  hardware.display = {
    edid.enable = true;
    edid.packages = [ edid-custom ];
    outputs."${sys-connector}".edid = "custom.edid";
  };
}
