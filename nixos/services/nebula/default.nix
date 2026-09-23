{ config, pkgs, lib, ... }:

let
  nodes = import ./nodes.nix;
  exts = lib.lists.flatten (
    builtins.map (ha: ha.int) (
      lib.attrsets.attrValues
        (lib.attrsets.filterAttrs (_: ha: ha ? ext) nodes)
    )
  );
  hostCfg = nodes.${config.networking.hostName};
  certsFile = builtins.readFile ../../../misc/pubkeys/nebula.toml;
  certs = builtins.fromTOML certsFile;
  cert = certs.${config.networking.hostName};
  certFile = pkgs.writeText "nebula.cert" ''
    -----BEGIN NEBULA CERTIFICATE-----
    ${cert}
    -----END NEBULA CERTIFICATE-----
  '';
in
{
  services.nebula.networks.unboiled = {
    settings = {
      listen = { host = "[::]"; port = 4242; };
      static_map.network = if hostCfg ? v6 && hostCfg.v6 then "ip6" else "ip";
      logging = {
        level = "info";
        format = "text";
      };
      routines = hostCfg.routines or 1;
      tun.mtu = "1300";
      punchy = {
        punch = true;
        respond = true;
        delay = "2s";
        respond_delay = "10s";
      };
    };
    tun.device = "unboiled";

    lighthouses = exts;
    relays = exts;
    isLighthouse = hostCfg ? ext;
    isRelay = hostCfg ? ext;

    staticHostMap = lib.attrsets.mapAttrs' (_: hostattrs:
      lib.attrsets.nameValuePair
        hostattrs.int
        (builtins.map (ip: ip + ":4242") hostattrs.ext)
    ) (lib.attrsets.filterAttrs (_: ha: ha ? ext) nodes);

    ca = ./ca;
    cert = certFile;
    # TODO 2024: make it just /mnt/secrets/nebula
    key =
      lib.mkDefault "/mnt/persist/secrets/nebula/${config.networking.hostName}";

    firewall.inbound = [ { host = "any"; port = "any"; proto = "any"; } ];
    firewall.outbound = [ { host = "any"; port = "any"; proto = "any"; } ];
  };
  # TODO 2024: not needed anymore
  systemd.services.perms-nebula = {
    description = "Change permissions for nebula";
    before = [ "nebula@unboiled.service" ];
    wantedBy = [ "nebula@unboiled.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart =
        "${pkgs.coreutils}/bin/chown -R nebula-unboiled" +
        " /mnt/persist/secrets/nebula";
    };
  };
  networking.firewall.allowedUDPPorts = [ 4242 ];
}
