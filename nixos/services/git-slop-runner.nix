{ config, ... }:

{
  services.gitea-actions-runner.instances.slop = {
    enable = true;
    url = "https://git.slop.unboiled.info";
    name = config.networking.hostName;
    tokenFile = "/mnt/secrets/gitea-runner/slop";
    labels = [
      #"ubuntu-latest:docker://docker.gitea.com/runner-images:ubuntu-latest"
      "ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-latest"
    ];
    settings = {
      runner.capacity = 1;
      cache.enabled = true;
      container.network = "host";
      #container.options = "-e NIX_REMOTE=daemon -v /nix/:/nix/ -v /nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket";
      #container.valid_volumes = [ "/nix/" ];
    };
  };

  virtualisation.podman.enable = true;
  virtualisation.podman.defaultNetwork.settings.dns_enable = true;
  networking.firewall.interfaces."podman+" = {
    allowedUDPPorts = [ 53 ];
    allowedTCPPorts = [ 53 ];
  };

  environment.persistence."/mnt/persist".directories = [
    { directory = "/var/lib/private"; mode = "0700"; }
    "/var/lib/private/gitea-runner"
    "/var/lib/containers"
    "/var/tmp"
  ];
}
