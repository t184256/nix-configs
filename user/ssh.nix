{ ... }:

{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      fig = { user = "monk"; hostname = "fig.unboiled.info"; };
      flaky = { user = "monk"; hostname = "192.168.100.220";
                extraOptions = {ProxyJump = "fig";}; };
      mango = { user = "monk"; hostname = "mango.unboiled.info"; };
      duckweed = { user = "monk"; hostname = "duckweed.unboiled.info"; };
      loquat = { user = "monk"; hostname = "loquat.unboiled.info"; };
      jungle = { user = "root"; hostname = "jungle.lan"; };
    };
  };
}
