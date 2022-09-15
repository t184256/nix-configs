{ pkgs, ... }:

{
  imports = [ ./wraplings.nix ];
  home.packages = with pkgs; [ hledger hledger-ui ];
  home.wraplings.hl = "${pkgs.hledger}/bin/hledger";
}
