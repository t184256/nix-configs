{ pkgs, lib, config, ... }:

let
  deviceIDs' = builtins.readFile ../../misc/pubkeys/syncthing.toml;
  deviceIDs = builtins.fromTOML deviceIDs';
  storageDir = "/mnt/storage";  # mountpoint
  secret = "${storageDir}/secrets/syncthing";  # file
  dataDir = "${storageDir}/sync";  # nodatacow subvolume
  servicesParentDir = "/mnt/storage/services";  # subvolume
  serviceDir = "${servicesParentDir}/syncthing";  # nodatacow subvolume
  databaseDir = "${serviceDir}/db";  # dir
  configDir = "${serviceDir}/cfg";  # dir
  keyDir = "${serviceDir}/key";  # dir
  key = "${keyDir}/key.pem";
  cert = "${keyDir}/cert.pem";

  allDirDevices = [ "fig" "olosapo" "quince" "sloe" "watermelon" ];
  mkFolder = name: extraAttrs: {
    path = lib.mkDefault "${dataDir}/${name}";
    type = lib.mkDefault "receiveonly";
    devices = allDirDevices ++ (extraAttrs.extraDevices or []);
    versioning = lib.mkDefault {
      type = "staggered";
      # fsPath = ".stversions";  # default
      params = {
        cleanInterval = "3600";
        maxAge = "31536000";
      };
    };
    fsWatcherEnabled =
      let t = extraAttrs.type or "receiveonly";  # not ideal if overridden later
      in t == "receiveonly" || t == "receiveencrypted";
  } // (lib.attrsets.filterAttrs (n: _: n != "extraDevices") extraAttrs);
in
{

  services.syncthing = {
    enable = true;
    #user = "monk";
    #group = "users";
    inherit dataDir databaseDir configDir key cert;
    overrideDevices = true;  # override WebUI
    overrideFolders = true;  # override WebUI
    openDefaultPorts = true;
    settings = {
      options = {
        urAccepted = -1;  # no usage reports
        relaysEnabled = true;
        localAnnounceEnabled = lib.mkDefault false;
        listenAddresses = [
          "quic://:22000"
          "tcp://:22000"
          "dynamic+http://127.0.0.1:22927/relays"
        ];
      };
      devices = {
        carambola.id = deviceIDs.carambola;
        coconut.id = deviceIDs.coconut;
        fig.id = deviceIDs.fig;
        olosapo.id = deviceIDs.olosapo;
        quince.id = deviceIDs.quince;
        sloe.id = deviceIDs.sloe;
        tamarillo.id = deviceIDs.tamarillo;
        watermelon.id = deviceIDs.watermelon;
      };
      folders = {
        # TODO: milder/no versioning on non-servers
        "android-shared" = mkFolder "android-shared" {
          extraDevices = [ "carambola" ];
        };
        "books" = mkFolder "books" {
          extraDevices = [ "carambola" "coconut" ];
        };
        "DecSync" = mkFolder "DecSync" {
          id = "8u43w-prlse";  # TODO: reinit on next reinstall
          extraDevices = [ "carambola" ];
        };
        "Librera" = mkFolder "Librera" {
          extraDevices = [ "carambola" "coconut" ];
        };
        "camera" = mkFolder "camera" { extraDevices = [ "carambola" ]; };
        "documents" = mkFolder "documents" { extraDevices = [ "carambola" ]; };
        "livestreams" = mkFolder "livestreams" {
          id = "jeiod-gytgw";  # TODO: reinit on fixing
          extraDevices = [ "carambola" "coconut" ];
        };
        "music" = mkFolder "music" { id = "music-dirty"; };
        "notes" = mkFolder "notes" { extraDevices = [ "carambola" ]; };
        "system" = mkFolder "system" { };
        "tracks" = mkFolder "tracks" {
          extraDevices = [ "carambola" "tamarillo" ];
        };
        "video" = mkFolder "video" {
          extraDevices = [ "carambola" "coconut" ];
        };
        "voice" = mkFolder "voice" {
          extraDevices = [ "carambola" "tamarillo" ];
        };
        "voice-raw" = mkFolder "voice-raw" { extraDevices = [ "carambola" ]; };
      };
    };
  };

  systemd.services.syncthing-preconfigure = {
    requires = [ "mnt-storage.mount" ];
    after = [ "mnt-storage.mount" ];
    requiredBy = [ "syncthing.service" ];
    before = [ "syncthing.service" ];
    partOf = [ "syncthing.service" ];
    bindsTo = [ "syncthing.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [ coreutils btrfs-progs e2fsprogs gnutar util-linux ];
    script =
      let
        chowner = let s = config.services.syncthing; in "${s.user}:${s.group}";
      in
      ''
        set -Eeuxo pipefail; shopt -s inherit_errexit
        mountpoint -q "${storageDir}"
        [[ -e "${servicesParentDir}" ]] || \
          btrfs subvol create "${servicesParentDir}"
        if [[ ! -e "${dataDir}" ]]; then
          btrfs subvol create "${dataDir}"
          chattr +C "${dataDir}"
          chown ${chowner} "${dataDir}"
        fi
        if [[ ! -e "${serviceDir}" ]]; then
          btrfs subvol create "${serviceDir}"
          chattr +C "${serviceDir}"
          chown ${chowner} "${serviceDir}"
        fi
        if [[ ! -e "${databaseDir}" ]]; then
          mkdir -p "${databaseDir}"
          chown ${chowner} "${databaseDir}"
        fi
        if [[ ! -e "${configDir}" ]]; then
          mkdir -p "${configDir}"
          chmod -x "${configDir}"
          chown ${chowner} "${configDir}"
        fi
        if [[ ! -e "${key}" || ! -e "${cert}" ]]; then
          mkdir -p "${keyDir}"
          chmod 400 "${keyDir}"
          tar -xvf "${secret}" -C "${keyDir}"
          chown ${chowner} "${configDir}" "${key}" "${cert}"
        fi
      '';
  };

  systemd.services.syncthing = {
    wantedBy = [ "storage.target" ];
    partOf = [
      "storage.target" "syncthing-init.service" "syncthing-preconfigure.service"
    ];
    environment.STNODEFAULTFOLDER = "true";
  };

  systemd.services.syncthing-relaylist = {
    requires = [ "mnt-storage.mount" ];
    after = [ "mnt-storage.mount" ];
    wantedBy = [ "syncthing.service" ];
    before = [ "syncthing.service" ];
    partOf = [ "syncthing.service" ];
    bindsTo = [ "syncthing.service" ];
    script = ''
      set -Eeuxo pipefail; shopt -s inherit_errexit
      cd /run/credentials/syncthing-relaylist.service
      exec ${pkgs.busybox}/bin/busybox httpd -vf -p 127.0.0.1:22927
    '';
    serviceConfig.Type = "exec";  # nixpkgs#258371
    serviceConfig.LoadCredential =
      "relays:/mnt/storage/secrets/syncthing-relays";
  };
}
