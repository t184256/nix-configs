{ config, pkgs, ... }:

{
  programs.neovim = {
    enable = true;

    withPython = false;  # it's 2020!
    withRuby = false;
    #withNodeJs = true;

    extraPackages = with pkgs; [];
    extraPython3Packages = (ps: with ps; []);
  };
}
