{ pkgs, ... }:

{
  nix.package = pkgs.nixFlakes;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
    builders-use-substitutes = true
    cores = 0
    keep-outputs = true
    log-lines = 20
    max-jobs = auto
  '';
}
