{ pkgs, config, ... }:
{
  # TODO 2024: make it just /mnt/secrets/nebula
  services.nebula.networks.unboiled.key =
    "/run/credentials/nebula@unboiled.service/nebula";
  systemd.services."nebula@unboiled".serviceConfig.LoadCredential =
    "nebula:/mnt/secrets/nebula";
  systemd.services.perms-nebula.enable = false;
}
