{ pkgs, ... }:

{
  nix.package = pkgs.nixFlakes;
  nix.extraOptions = ''
    extra-substituters = https://nix-cache.unboiled.info
    trusted-public-keys = nix-cache.unboiled.info-1:P/F71h2Fc7jfhxsoefISVYBfq0vALOMCIxEEmvtmpMg= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
    experimental-features = nix-command flakes
    builders-use-substitutes = true
    log-lines = 20
    cores = 0
    max-jobs = auto
  '';
}
