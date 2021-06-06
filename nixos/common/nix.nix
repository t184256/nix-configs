{ pkgs, ... }:

{
  nix.package = pkgs.nixFlakes;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
    builders-use-substitutes = true
    log-lines = 20
    cores = 0
    max-jobs = auto
  '';
}
