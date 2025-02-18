{ pkgs, ... }:

{
  # also installed user-wide for non-NixOS, see user/assorted-tools.nix
  environment.systemPackages = with pkgs; [ nps ];

  environment.sessionVariables = {
    NIX_PACKAGE_SEARCH_COLUMNS = "version";  # nps#22
    NIX_PACKAGE_SEARCH_EXPERIMENTAL = "true";  # flakes
    NIX_PACKAGE_SEARCH_PRINT_SEPARATOR = "false";  # compact output
    NIX_PACKAGE_SEARCH_CACHE_FOLDER_ABSOLUTE_PATH = "/var/cache/nps";
    NIX_PACKAGE_SEARCH_EXACT_COLOR = "green";
    NIX_PACKAGE_SEARCH_DIRECT_COLOR = "blue";
    NIX_PACKAGE_SEARCH_INDIRECT_COLOR = "magenta";
  };

  systemd.services."nps-refresh-cache" = {
    requires = [ "var-cache-nps.mount" ];
    after = [ "var-cache-nps.mount" ];
    path = ["/run/current-system/sw/"];
    serviceConfig = {
      Type = "oneshot";
      User = "monk";
    };
    environment = {
      NIX_PACKAGE_SEARCH_EXPERIMENTAL = "true";  # flakes
      NIX_PACKAGE_SEARCH_CACHE_FOLDER_ABSOLUTE_PATH = "/var/cache/nps";
    };
    script = "${pkgs.nps}/bin/nps -r -dddd";
  };
  systemd.timers."nps-refresh-cache" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      Unit = "nps-refresh-cache.service";
    };
  };

  #home-manager.users.monk.home.persistence."/mnt/persist" = {
  environment.persistence."/mnt/persist" = {
    directories = [
      { directory = "/var/cache/nps"; user = "monk"; }
    ];
  };
}
