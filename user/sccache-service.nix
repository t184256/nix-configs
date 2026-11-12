{ config, pkgs, lib, ... }:

let
  cfg = config.programs.sccache;
in
{
  options.programs.sccache = {
    enable = lib.mkEnableOption "sccache compiler cache user service";

    dir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.xdg.cacheHome}/sccache";
      description = "sccache cache directory";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.sccache = {
      Unit.Description = "sccache compiler cache daemon";
      Service = {
        Type = "forking";  # track the daemonized server
        Restart = "on-failure";
        Environment = [
          "SCCACHE_DIR=${cfg.dir}"
          "SCCACHE_IDLE_TIMEOUT=0"
        ];
        ExecStart = "${pkgs.sccache}/bin/sccache --start-server";
        ExecStop = "${pkgs.sccache}/bin/sccache --stop-server";
      };
    };
  };
}
