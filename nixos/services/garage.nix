{ pkgs, lib, config, ... }:

let
  pubkeys' = builtins.readFile ../../misc/pubkeys/garage.toml;
  pubkeys = builtins.fromTOML pubkeys';
  ownPubkey = pubkeys.${config.networking.hostName};
in
{
  services.garage = {
    enable = true;
    package = pkgs.garage_1_2_0;
    settings = {
      data_dir = lib.mkDefault "/mnt/storage/garage/data";
      metadata_dir = lib.mkDefault "/mnt/storage/garage/meta";
      db_engine = "sqlite";
      block_size = "2M";
      replication_factor = 5;
      consistency_mode = "consistent";
      block_ram_buffer_max = lib.mkDefault "64M";  # raise for upload nodes
      s3_api = {
        api_bind_addr = "[::]:3900";
        root_domain = ".s3.garage.unboiled.info";
        s3_region = "garage";
      };
      rpc_bind_addr = "[::]:3901";
      #rpc_public_addr = "127.0.0.1:3901"
      #s3_web.bind_addr = "[::]:3902";
      #s3_web.root_domain = ".web.garage.unboiled.info";
      #admin.api_bind_addr = "[::]:3903";
      # GARAGE_RPC_SECRET_FILE
      # GARAGE_ADMIN_TOKEN_FILE
      # GARAGE_METRICS_TOKEN_FILE
      bootstrap_peers = [
        "${pubkeys.cocoa}@192.168.99.7:3901"
        "${pubkeys.watermelon}@watermelon.unboiled.info:3901"
        "${pubkeys.sloe}@sloe.unboiled.info:3901"
        "${pubkeys.olosapo}@olosapo.unboiled.info:3901"
        "${pubkeys.quince}@192.168.99.6:3901"
      ];
      allow_world_readable_secrets = true;  # mode: 0100440
      rpc_secret_file = "/run/credentials/garage.service/rpc";
    };
  };

  users = {
    users.garage.isSystemUser = true;
    users.garage.group = "garage";
    groups.garage = {};
  };

  systemd.services.garage = {
    wantedBy = [ "storage.target" ];
    partOf = [
      "storage.target" "garage-preconfigure.service"
    ];
    serviceConfig = {
      DynamicUser = false;
      User = "garage";
      Group = "garage";
      StateDirectory = "/mnt/storage/garage";
      LoadCredential = [
        "rpc:/mnt/storage/secrets/garage/rpc"
      ];
    };
  };

  systemd.services.garage-preconfigure = {
    requires = [ "mnt-storage.mount" ];
    after = [ "mnt-storage.mount" ];
    requiredBy = [ "garage.service" ];
    before = [ "garage.service" ];
    partOf = [ "garage.service" ];
    bindsTo = [ "garage.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [ coreutils btrfs-progs e2fsprogs gnutar util-linux ];
    script =
      let
        c = config.systemd.services.garage.serviceConfig;
      in
      ''
        set -Eeuxo pipefail; shopt -s inherit_errexit
        mountpoint -q /mnt/storage
        [[ -e /mnt/storage/garage ]] || btrfs subvol create /mnt/storage/garage
        [[ -e /mnt/storage/garage/data ]] || \
          btrfs subvol create /mnt/storage/garage/data
        chattr +C /mnt/storage/garage/data
        chown "${c.User}:${c.Group}" /mnt/storage/garage/data
        [[ -e /mnt/storage/garage/meta ]] || \
          btrfs subvol create /mnt/storage/garage/meta
        chattr -C /mnt/storage/garage/meta
        chown "${c.User}:${c.Group}" /mnt/storage/garage/meta
        install -o "${c.User}" -g "${c.Group}" -m 400 \
          /mnt/storage/secrets/garage/priv /mnt/storage/garage/meta/node_key
        install -o "${c.User}" -g "${c.Group}" -m 400 \
          /mnt/storage/secrets/garage/rpc /mnt/storage/garage/meta/rpc
      '';
  };

  environment.systemPackages = [
    (pkgs.writeScriptBin "garagectl" ''
      #!/bin/sh
      export GARAGE_RPC_HOST=${ownPubkey}@127.0.0.1:3901
      exec garage "$@"
    '')
  ];

  networking.firewall.allowedTCPPorts = [ 3901 ];
}
