{ config, ... }:

{
  imports = [ ./config/os.nix ];
  programs.htop = {
    enable = true;
    colorScheme = 1;
    fields =
      if config.system.os != "Nix-on-Droid"
        then [ "USER" "PERCENT_CPU" "PERCENT_MEM" "TIME" "COMM" ]
        else [ "PID" "STATE" "PERCENT_MEM" "TIME" "COMM" ];
    headerMargin = false;
    hideThreads = true;
    hideUserlandThreads = true;
    highlightBaseName = true;
    meters.left =
      if config.system.os != "Nix-on-Droid"
        then [ "AllCPUs2" "Memory" "Swap" ]
        else [ "Memory" "Swap" ];
    meters.right =
      if config.system.os != "Nix-on-Droid"
        then [ { kind = "Battery"; mode = 1; } "Uptime" "Tasks" "LoadAverage"]
        else [ "Tasks" ];
    shadowOtherUsers = true;
    showCpuFrequency = true;
    showProgramPath = false;
    sortKey = "PERCENT_MEM";
  };
}
