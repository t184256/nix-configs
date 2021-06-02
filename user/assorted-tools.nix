{ pkgs, config, ... }:

{
  home.packages = with pkgs; [
    fd
    ripgrep
    hyperfine
  ];
}
