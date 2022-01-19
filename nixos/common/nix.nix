{ pkgs, ... }:

{
  nix.package = pkgs.nixFlakes;
  nix.extraOptions = ''
    trusted-users = monk
    extra-substituters = https://nix-cache.unboiled.info?priority=10
    trusted-public-keys = nix-cache.unboiled.info-1:P/F71h2Fc7jfhxsoefISVYBfq0vALOMCIxEEmvtmpMg= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
    experimental-features = nix-command flakes ca-derivations
    builders-use-substitutes = true
    narinfo-cache-negative-ttl = 300
    narinfo-cache-positive-ttl = 7200
    log-lines = 20
  '';
  nix.daemonCPUSchedPolicy = "batch";
  nix.daemonIOSchedClass = "idle";
  nix.daemonIOSchedPriority = -1;
}
