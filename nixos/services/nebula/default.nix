{ config, pkgs, lib, ... }:

let
  nodes = {
    loquat = { int = "192.168.99.1"; ext = [ "loquat.unboiled.info" ]; routines = 3; };
    duckweed = { int = "192.168.99.2"; ext = [ "duckweed.unboiled.info" ]; };
    bayroot = { int = "192.168.99.3"; v6 = true; };
    araceae = { int = "192.168.99.4"; v6 = true; };
    quince = { int = "192.168.99.6"; routines = 2; };
    cocoa = { int = "192.168.99.7"; routines = 10; };
    lychee = { int = "192.168.99.8"; routines = 2; };
  };
  exts = lib.lists.flatten (
    builtins.map (ha: ha.int) (
      lib.attrsets.attrValues
        (lib.attrsets.filterAttrs (_: ha: ha ? ext) nodes)
    )
  );
  hostCfg = nodes.${config.networking.hostName};
in
{
  services.nebula.networks.unboiled = {
    settings = {
      listen = { host = "[::]"; port = 4242; };
      static_map.network = if hostCfg ? v6 && hostCfg.v6 then "ip6" else "ip";
      punchy = { punch = true; respond = true; };
      logging = {
        level = "debug";
        format = "text";
      };
      routines = hostCfg.routines or 1;
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

    ca = ./certs/ca;
    cert = ./certs/${config.networking.hostName};
    key = "/mnt/persist/secrets/nebula/${config.networking.hostName}";

    firewall.inbound = [ { host = "any"; port = "any"; proto = "any"; } ];
    firewall.outbound = [ { host = "any"; port = "any"; proto = "any"; } ];
  };
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
