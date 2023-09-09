{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.home.wraplings;
in {
  options = {
    home.wraplings = mkOption {
      default = {};
      example = { ll = "ls -l"; };
      description = ''
        An attribute set that maps aliases (the top level attribute names in
        this option) to command strings or directly to build outputs. The
        result looks like aliases, but actually produces wrappers.
      '';
      type = types.attrsOf types.str;
    };
  };

  config = {
    # example:
    #  home.packages = with pkgs; [
    #    (pkgs.writeShellScriptBin "ll" "exec ${eza}/bin/eza -l")
    #  ];

    home.packages = (
      mapAttrsToList (
        n: v:
        (pkgs.writeShellScriptBin n ("exec " + v + " \"$@\""))
      ) cfg
    );
  };
}
