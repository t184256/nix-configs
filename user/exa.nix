{ pkgs, config, ... }:

{
  # calling exa directly
  home.packages = [ pkgs.exa ];

  # calling exa via wraplings
  home.wraplings = rec {
    l = "${pkgs.exa}/bin/exa --color=never -F -b";
    ll = l + " --time-style=iso -lm --git" + (
      if config.system.os == "Android" then "" else " -g"
    );
    la = l + " -a";
    lt = l + " -T";
  };
}
