{ config, ... }:

{
  services.gitea-actions-runner.instances.slop = {
    url = "https://git.slop.unboiled.info";
    tokenFile = "/mnt/secrets/gitea-runner/slop";
    name = config.networking.hostName;
};
