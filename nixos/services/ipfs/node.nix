{ config, lib, ... }:

let
  swarmKeyPath = if config.networking.hostName != "quince"
    then "/mnt/persist/secrets/ipfs/swarm.key"
    else "/mnt/storage/secrets/ipfs/swarm.key";
  lateStorage = config.networking.hostName == "quince";
  ifStorage = a: if lateStorage then a else [];
in
{
  services.kubo = {
    enable = true;
    enableGC = true;
    dataDir = "/mnt/storage/ipfs";
    localDiscovery = false;  # explicit
    emptyRepo = true;
    settings = {
      Bootstrap = [
        # duckweed
        "/ip4/51.15.87.8/tcp/4001/p2p/12D3KooWEfb5fp1jjsjPpzL5vQ8HeUiiaE2ybzXVPbVxzS1qciBZ"
        # loquat
        "/ip4/38.242.239.104/tcp/4001/p2p/12D3KooWQnJWfBhRxy718TYWUhd5JXjTuo1nRxmXJ5NTUi47ceEK"
        "/ip6/2a02:c206:2101:9233::1/tcp/4001/p2p/12D3KooWQnJWfBhRxy718TYWUhd5JXjTuo1nRxmXJ5NTUi47ceEK"
      ];
      Datastore = {
        StorageMax = lib.mkDefault "512MB";
        GCPeriod = lib.mkDefault "1h";
      };
      Discovery.MDNS.Enabled = false;
      Addresses = {
        API = "/ip4/127.0.0.1/tcp/4003";
        Gateway = "/ip4/127.0.0.1/tcp/4004";
      };
    };
  };
  systemd.services = {
    ipfs-preconfigure = {
      wantedBy = ifStorage [ "mnt-storage.target" ];
      requires = ifStorage [ "mnt-storage.mount" ];
      after = ifStorage [ "mnt-storage.mount" "mnt-storage.target" ];
      partOf = ifStorage [ "mnt-storage.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -uexo pipefail
        export IPFS_PATH="${config.services.kubo.dataDir}"
        install \
          -o "${config.services.kubo.user}" -g "${config.services.kubo.group}" \
          -m 770 -d "$IPFS_PATH"
        if [[ ! -e "$IPFS_PATH/swarm.key" ]]; then
          chown "${config.services.kubo.user}" ${swarmKeyPath}
          chmod 400 ${swarmKeyPath}
          ln -sf ${swarmKeyPath} "$IPFS_PATH/"
        fi
        if [[ ! -e "$IPFS_PATH/config" ]]; then
          ${config.services.kubo.package}/bin/ipfs init \
            --algorithm ed25519 \
            --empty-repo=${lib.boolToString config.services.kubo.emptyRepo}
          ${config.services.kubo.package}/bin/ipfs bootstrap rm --all
          chown -R \
            "${config.services.kubo.user}:${config.services.kubo.group}" \
            "$IPFS_PATH"
        fi
        exit 0
      '';
    };
    ipfs = {
      requires =
        [ "ipfs-preconfigure.service" ] ++
        ifStorage [ "mnt-storage.mount" ];
      wantedBy = ifStorage [ "mnt-storage.target" ];
      after =
        [ "ipfs-preconfigure.service" ] ++
        ifStorage [ "mnt-storage.mount" "mnt-storage.target" ];
      partOf = ifStorage [ "mnt-storage.target" ];
      environment.LIBP2P_FORCE_PNET = "1";
    };
  };
  users.users.monk.extraGroups = [ config.services.kubo.group ];
  networking.firewall.allowedTCPPorts = [ 4001 ];
  networking.firewall.allowedUDPPorts = [ 4001 ];

  # Note to self, swarm.key generation:
  # echo -e '/key/swarm/psk/1.0.0/\n/base16/' > swarm.key
  # head -c 32 /dev/urandom | od -t x1 -A none - | tr -d '\n ' >> swarm.key
  # echo >> swarm.key
  # chmod 400 ipfs swarm.key
  # chown ipfs swarm.key
}
