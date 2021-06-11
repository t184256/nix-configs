{ pkgs, config, ... }:

{
  imports = [ ./wraplings.nix ./config/os.nix ];

  # calling exa directly
  programs.exa.enable = true;

  # calling exa via wraplings
  home.wraplings = rec {
    l = "${pkgs.exa}/bin/exa --group-directories-first --sort Name -F -b";
    ll = l + " --time-style=iso -lm --git" + (
      if config.system.os == "Android" then "" else " -g"
    );
    la = l + " -a";
    lt = l + " -T";
    lla = l + " -la";
  };
}
