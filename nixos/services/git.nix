{ pkgs, config, ... }:

{
  services.forgejo = {
    enable = true;
    stateDir = "/mnt/storage/services/forgejo";
    user = "git";  # I like my repo urls short
    database.user = "git";  # must match
    database.type = "sqlite3";  # default, but just in case
    settings = {
      cache = {
        ADAPTER = "twoqueue";
        HOST = "{\"size\": 100, \"recent_ratio\":0.25, \"ghost_ratio\":0.5}";
        INTERVAL = 180;
      };
      server = {
        DOMAIN = "git.unboiled.info";
        HTTP_ADDRESS = "127.0.0.1";
        HTTP_PORT = 3000;
        ROOT_URL = "https://git.unboiled.info";
      };
      service = {
        DISABLE_REGISTRATION = true;  # 1st user becomes an admin.
        REQUIRE_SIGNIN_VIEW = true;
      };
      session.COOKIE_SECURE = true;
      DEFAULT.APP_NAME = "monk's private forgejo";
    };
  };
  users.extraUsers.git = {
    description = "Forgejo Service";
    home = config.services.forgejo.stateDir;
    createHome = true;
    useDefaultShell = true;
    isSystemUser = true;
    group = "forgejo";
  };

  services.nginx = {
    enable = true;
    virtualHosts."git.unboiled.info" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:3000";
    };
  };

  systemd.services.forgejo = {
    serviceConfig = {
      CPUAffinity = "0-1";
      MemoryHigh = "768M"; MemoryMax = "1G";  # anecdotal mem peak is 252M
    };
    wantedBy = [ "storage.target" ];
    partOf = [ "storage.target" "forgejo-preconfigure.service" ];
  };
  systemd.services.forgejo-preconfigure = {
    requires = [ "mnt-storage.mount" ];
    after = [ "mnt-storage.mount" ];
    requiredBy = [ "forgejo.service" "forgejo-secrets.service" ];
    before = [ "forgejo.service" "forgejo-secrets.service" ];
    partOf = [ "forgejo.service" ];
    bindsTo = [ "forgejo.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    path = with pkgs; [ coreutils btrfs-progs util-linux ];
    script = ''
      set -Eeuxo pipefail; shopt -s inherit_errexit
      mountpoint -q /mnt/storage
      [[ "${config.services.forgejo.stateDir}" == /mnt/storage/services/* ]]
      if ! btrfs subvolume show "${config.services.forgejo.stateDir}" \
           > /dev/null; then
        [[ -e "${config.services.forgejo.stateDir}" ]] && \
          rm -d "${config.services.forgejo.stateDir}"
        btrfs subvol create "${config.services.forgejo.stateDir}"
        chown \
          "${config.services.forgejo.user}:${config.services.forgejo.group}" \
          "${config.services.forgejo.stateDir}"
      fi
      systemd-tmpfiles --create --prefix="${config.services.forgejo.stateDir}"
    '';
  };

  services.restic.backups.forgejo = {
    environmentFile = "/mnt/storage/secrets/restic/forgejo/key";
    passwordFile = "/mnt/storage/secrets/restic/forgejo/pass";
    paths = [ "service-forgejo" ];
    repository =
      "s3:http://localhost:3900/service-forgejo-"
      + config.networking.hostName;
    pruneOpts = [ "--keep-daily 30" "--keep-weekly 30" "--keep-monthly 30" ];
    backupPrepareCommand = ''
      ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r \
        ${config.services.forgejo.stateDir} \
        /mnt/storage/tmp/service-forgejo
    '';
    backupCleanupCommand = ''
      ${pkgs.btrfs-progs}/bin/btrfs subvolume delete \
        /mnt/storage/tmp/service-forgejo
    '';
  };
  systemd.services.restic-backups-forgejo = {
    serviceConfig.WorkingDirectory = "/mnt/storage/tmp";
    requires = [ "mnt-storage-tmp.service" ];
    after = [ "mnt-storage-tmp.service" ];
  };
}
