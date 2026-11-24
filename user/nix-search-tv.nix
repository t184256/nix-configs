{ config, lib, pkgs, specialArgs, ... }:

let
  cfg = config.nix-search-tv;
in
{
  options.nix-search-tv.enable = lib.mkEnableOption "fuzz nix-related search";

  config = lib.mkIf cfg.enable (
    {
      programs.nix-search-tv = {
        enable = true;
        settings = {
          indexes = [ "nixpkgs" "nixos" "home-manager" "nur" "noogle" ];
          # keep in sync with the refresh timer below
          update_interval = "168h";
        };
      };

      home.persistence."/mnt/persist".directories = [
        { directory = ".cache/nix-search-tv"; }
      ];

      systemd.user.services."nix-search-tv" = {
        Unit.Description = "Refresh nix-search-tv indexes";
        Service = {
          Type = "oneshot";
          TimeoutStartSec = "5min";  # pulls ~200M
          ExecStart = "${pkgs.nix-search-tv}/bin/nix-search-tv print";
          StandardOutput = "null";
        };
      };

      systemd.user.timers."nix-search-tv" = {
        Unit.Description = "Refresh nix-search-tv indexes";
        Timer.OnUnitInactiveSec = "168h";
        Install.WantedBy = [ "timers.target" ];
      };
    }
  );
}
