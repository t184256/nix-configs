{ pkgs, ... }:

{
  nix.package = pkgs.nixFlakes;
  nix.settings = {
    substituters = [ "https://hydra.unboiled.info?priority=200" ];
    trusted-public-keys = [
      "hydra.nixos.org-1:CNHJZBh9K4tP3EKF6FkkgeVYsS3ohTl+oS0Qa8bezVs="
      "hydra.unboiled.info-1:c7i8vKOB30a+DaJ2M04F0EM8CPRfU+WpbqWie4n221M="
    ];
  };
  nix.extraOptions = ''
    trusted-users = monk
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
