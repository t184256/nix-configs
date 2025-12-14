{ pkgs, ... }:

{
  nixpkgs.overlays = [ (import ../overlays/mosh) ];
  home.packages = [ pkgs.mosh ];
}
