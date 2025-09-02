_ :

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      fig = { user = "monk"; hostname = "fig.unboiled.info"; };
      mango = { user = "monk"; hostname = "mango.unboiled.info"; };
      duckweed = { user = "monk"; hostname = "duckweed.unboiled.info"; };
      loquat = { user = "monk"; hostname = "loquat.unboiled.info"; };
      jungle = { user = "root"; hostname = "jungle.lan"; };
      bayroot = { user = "monk"; hostname = "192.168.99.3"; };
      araceae = { user = "monk"; hostname = "192.168.99.4"; };
      quince = { user = "monk"; hostname = "duckweed.unboiled.info";
                port = 226; };
      cocoa = { user = "monk"; hostname = "duckweed.unboiled.info";
                port = 227; };
      sloe = { user = "monk"; hostname = "sloe.unboiled.info"; };
      olosapo = { user = "monk"; hostname = "olosapo.unboiled.info"; };
      watermelon = { user = "monk"; hostname = "watermelon.unboiled.info"; };
      etrog = { user = "monk"; hostname = "etrog.unboiled.info"; };
      iyokan = { user = "monk"; hostname = "iyokan.unboiled.info"; };

      bayroot64 = {
        user = "monk";
        hostname = "bayroot.unboiled.info";
        proxyJump = "duckweed";
      };
      araceae64 = {
        user = "monk";
        hostname = "araceae.unboiled.info";
        proxyJump = "duckweed";
      };
    };
  };
}
