{ pkgs, config, ... }:

{
  imports = [ ./wraplings.nix ./config/os.nix ];

  # calling eza directly
  programs.eza.enable = true;

  # calling eza via wraplings
  home.wraplings = rec {
    l = "${pkgs.eza}/bin/eza --group-directories-first --sort Name -F -b";
    ll = l + " --time-style=iso -lm --git" + (
      if config.system.os == "Android" then "" else " -g"
    );
    la = l + " -a";
    lt = l + " -T";
    lla = ll + " -a";
  };
}
