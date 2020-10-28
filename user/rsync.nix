{ pkgs, ... }:

{
  home.packages = [ pkgs.rsync ];
  home.wraplings.rs = "${pkgs.rsync}/bin/rsync -r --no-i-r --info=progress2";
}
