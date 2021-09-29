{ pkgs, config, ... }:

{
  home.packages = with pkgs; [
    pv
    fd
    ripgrep
    tokei
    hyperfine
  ];
}
