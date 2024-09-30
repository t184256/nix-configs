_:

{
  nix = {
    settings = {
      substituters = [ "https://hydra.unboiled.info?priority=200" ];
    };
    settings.trusted-users = [ "monk" ];
    extraOptions = ''
      experimental-features = nix-command flakes cgroups ca-derivations
      use-cgroups = true
      builders-use-substitutes = true
      narinfo-cache-negative-ttl = 300
      narinfo-cache-positive-ttl = 7200
      log-lines = 20
    '';
    daemonCPUSchedPolicy = "batch";
    daemonIOSchedClass = "idle";
  };
}
