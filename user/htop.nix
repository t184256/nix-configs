{ config, pkgs, ... }:

{
  programs.htop = {
    enable = true;
    colorScheme = 1;
    fields = [ "USER" "PERCENT_CPU" "PERCENT_MEM" "TIME" "COMM" ];
    headerMargin = false;
    hideThreads = true;
    hideUserlandThreads = true;
    highlightBaseName = true;
    meters.left = [ "AllCPUs2" "Memory" "Swap" ];
    meters.right = [ { kind = "Battery"; mode = 1; } "Uptime" "Tasks" "LoadAverage" ];
    shadowOtherUsers = true;
    showCpuFrequency = true;
    showProgramPath = false;
    sortKey = "PERCENT_MEM";
  };
}
