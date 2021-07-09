{ config, pkgs, ... }:

{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      fig = { user = "monk"; hostname = "fig.unboiled.info"; };
      mango = { user = "monk"; hostname = "mango.unboiled.info"; };
      duckweed = { user = "monk"; hostname = "duckweed.unboiled.info"; };
      jungle = { user = "root"; hostname = "jungle.lan"; };
    };
  };
}
