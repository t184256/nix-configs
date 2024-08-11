{ pkgs, config, ... }:
{
  # TODO 2024: make it the default
  services.nebula.networks.unboiled.cert =
    let
      certsFile = builtins.readFile ../../../misc/pubkeys/nebula.toml;
      certs = builtins.fromTOML certsFile;
      cert = certs.${config.networking.hostName};
    in
    pkgs.writeText "nebula.cert" ''
      -----BEGIN NEBULA CERTIFICATE-----
      ${cert}
      -----END NEBULA CERTIFICATE-----
    '';
  # TODO 2024: make it just /mnt/secrets/nebula
  services.nebula.networks.unboiled.key =
    "/run/credentials/nebula@unboiled.service/nebula";
  systemd.services."nebula@unboiled".serviceConfig.LoadCredential =
    "nebula:/mnt/secrets/nebula";
  systemd.services.perms-nebula.enable = false;
}
