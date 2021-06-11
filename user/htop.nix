{ config, ... }:

{
  imports = [ ./config/os.nix ];
  programs.htop.enable = true;
  programs.htop.settings = {
    color_scheme = 1;
    fields = with config.lib.htop.fields;
      if config.system.os != "Nix-on-Droid"
        then [ USER PERCENT_CPU PERCENT_MEM TIME COMM ]
        else [ PID STATE PERCENT_MEM TIME COMM ] ;
    header_margin = false;
    hide_threads = true;
    hide_kernel_threads = true;
    hide_userland_threads = true;
    highlight_base_name = true;
    highlight_megabytes = true;
    shadow_other_users = true;
    show_cpu_frequency = true;
    show_program_path = false;
    sort_key = config.lib.htop.fields.PERCENT_MEM;
  } // (with config.lib.htop; leftMeters (
    if config.system.os != "Nix-on-Droid"
    then [
      (bar "AllCPUs2")
      (bar "Memory")
      (bar "Swap")
    ] else [
      (bar "Memory")
      (bar "Swap")
    ]
  )) // (with config.lib.htop; rightMeters (
    if config.system.os != "Nix-on-Droid"
    then [
      (bar "Battery")
      (text "Uptime")
      (text "Tasks")
      (text "LoadAverage")
    ] else [
      (text "Tasks")
    ]
  ));
}
