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

  allDirDevices = [ "fig" "quince" "watermelon" ];
  mkFolder = name: extraAttrs: {
    path = lib.mkDefault "${dataDir}/${name}";
    type = lib.mkDefault "receiveonly";
    devices = allDirDevices;
    versioning = lib.mkDefault {
      type = "staggered";
      # fsPath = ".stversions";  # default
      params = {
        cleanInterval = "3600";
        maxAge = "31536000";
      };
    };
  } // extraAttrs;
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
        quince.id = deviceIDs.quince;
        watermelon.id = deviceIDs.watermelon;
      };
      folders = {
        # TODO: versioning
        "books" = mkFolder "books" {
          devices = allDirDevices ++ [ "carambola" "coconut" ];
        };
        "Librera" = mkFolder "Librera" {
          devices = allDirDevices ++ [ "carambola" "coconut" ];
        };
        "notes" = mkFolder "notes" {
          devices = allDirDevices ++ [ "carambola" ];
        };
        "video" = mkFolder "video" {
          devices = allDirDevices ++ [ "carambola" "coconut" ];
        };
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
    partOf = [ "storage.target" ];
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
