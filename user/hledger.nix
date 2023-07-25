{ pkgs, lib, config, ... }:

{
  imports = [ ./wraplings.nix ./config/live.nix ];
  home = lib.mkIf (! config.system.live) {
    packages = with pkgs; [ hledger hledger-ui ];
    wraplings = {
      hl = "${pkgs.hledger}/bin/hledger";
      vihl = "vi ~/.hledger.journal";
    };
  };
}
