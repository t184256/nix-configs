{ pkgs, config, lib, ... }:

let
  clusterConfig = {
    cluster = {
      replication_factor_min = 2;
      replication_factor_max = 3;
      disable_repinning = false;
      peername = config.networking.hostName;
      listen_multiaddress = [
        "/ip4/0.0.0.0/tcp/4011"
        "/ip4/0.0.0.0/udp/4011/quic"
        "/ip6/::/tcp/4011"
        "/ip6/::/udp/4011/quic"
      ];
      peer_addresses = [
        "/ip4/38.242.239.104/tcp/4011/p2p/12D3KooWBUCesQJecVHdZ8NHGKWy4LghW6X735gvMADDkUvMRr2W"
        "/ip6/2a02:c206:2101:9233::1/tcp/4011/p2p/12D3KooWBUCesQJecVHdZ8NHGKWy4LghW6X735gvMADDkUvMRr2W"
        #"/ip4/192.168.99.7/tcp/4011/p2p/12D3KooWFXh5giPXKQhuS4vevzuu8xXwm8GUASwPoW6ruLMhmQAR"
      ];
    };
    consensus.crdt = {
      cluster_name = "unboiled-info-ipfs-cluster";
      trusted_peers = [
        "12D3KooWBUCesQJecVHdZ8NHGKWy4LghW6X735gvMADDkUvMRr2W"  # loquat
        "12D3KooWFXh5giPXKQhuS4vevzuu8xXwm8GUASwPoW6ruLMhmQAR"  # cocoa
      ];
    };
    api.restapi.http_listen_multiaddress = "/ip4/127.0.0.1/tcp/4012";
    ipfs_connector.ipfshttp = {
      node_multiaddress = "/ip4/127.0.0.1/tcp/4003";
    };
    informer.disk = { metric_ttl = "30s"; metric_type = "freespace"; };
    datastore.pebble = {};
  };
  clusterConfigJson =
    pkgs.writeText "ipfs-cluster.json" (builtins.toJSON clusterConfig);
  clusterDir = "${config.services.kubo.dataDir}/cluster";
in
{
  systemd.services.ipfs-cluster = {
    wantedBy = [ "default.target" ];
    requires = [ "ipfs.service" ];
    after = [ "ipfs.service" ];
    environment.IPFS_PATH = config.services.kubo.dataDir;
    serviceConfig = {
      User = config.services.kubo.user;
      Group = config.services.kubo.group;
      EnvironmentFile = "/mnt/persist/secrets/ipfs/cluster.key";
      ExecStart = [
        ""
        "${pkgs.ipfs-cluster}/bin/ipfs-cluster-service -c ${clusterDir} daemon"
      ];
    };
    preStart = ''
      install \
        -o "${config.services.kubo.user}" -g "${config.services.kubo.group}" \
        -m 770 -d "${clusterDir}"
      touch "${clusterDir}/service.json"
      chown "${config.services.kubo.user}:${config.services.kubo.group}" \
        "${clusterDir}/service.json"
      chmod 600 "${clusterDir}/service.json"
      ${pkgs.jq}/bin/jq ".cluster.secret = \"$CLUSTER_SECRET\"" \
        ${clusterConfigJson} > "${clusterDir}/service.json"
      chmod 400 "${clusterDir}/service.json"
      ln -sf /mnt/persist/secrets/ipfs/cluster.id "${clusterDir}/identity.json"
    '';
  };
  networking.firewall.allowedTCPPorts = [ 4011 ];
  networking.firewall.allowedUDPPorts = [ 4011 ];
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "ipfsc" ''
      exec ${pkgs.ipfs-cluster}/bin/ipfs-cluster-ctl \
      -l /ip4/127.0.0.1/tcp/4012 "$@"
    '')
  ];
}
