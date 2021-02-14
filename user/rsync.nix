{ pkgs, ... }:

{
  home.packages = [ pkgs.rsync ];
  home.wraplings.rs = "${pkgs.rsync}/bin/rsync -rt --no-i-r --info=progress2";
}
