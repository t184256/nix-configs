{ pkgs, lib, config, ... }:

{
  imports = [ ./config/roles.nix ];
  config = lib.mkIf config.roles.slop {
    nixpkgs.overlays = [ (import ../overlays/gnhf.nix) ];
    home.packages = [ pkgs.gnhf ];
    home.file.".gnhf/config.yml".text = builtins.toJSON {
      agent = "pi";
      agentModel.pi = "batch";
      agentPathOverride.pi = "jailed-pi";
    };
  };
}
