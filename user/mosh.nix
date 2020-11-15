{ pkgs, ... }:

{
  nixpkgs.overlays = [ (import ../overlays/mosh.nix) ];
  home.packages = [ pkgs.mosh ];
}
