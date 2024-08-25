{ lib, config, ... }:

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
    #apps = [
    #  {
    #    name = "800x600@60";
    #    prep-cmd = [
    #      {
    #        do = "set resolution";
    #        undo = "set resolution";
    #      }
    #    ];
    #    exclude-global-prep-cmd = "false";
    #    auto-detach = "true";
    #  }
    #];
  };

  environment.persistence."/mnt/persist".users.monk.directories = [
    ".config/sunshine"
  ];
}
