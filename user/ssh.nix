{ ... }:

{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      fig = { user = "monk"; hostname = "fig.unboiled.info"; };
      mango = { user = "monk"; hostname = "mango.unboiled.info"; };
      duckweed = { user = "monk"; hostname = "duckweed.unboiled.info"; };
      loquat = { user = "monk"; hostname = "loquat.unboiled.info"; };
      jungle = { user = "root"; hostname = "jungle.lan"; };
      cashew = { user = "monk"; hostname = "duckweed.unboiled.info";
                 port = 221; };
      cocoa = { user = "monk"; hostname = "duckweed.unboiled.info";
                port = 223; };
    };
  };
}
