{ pkgs, lib, config, ... }:

let
  deviceIDs' = builtins.readFile ../../misc/pubkeys/syncthing.toml;
  deviceIDs = builtins.fromTOML deviceIDs';
  storageDir = "/mnt/storage";  # mountpoint
  secret = "${storageDir}/secrets/syncthing";  # file
  dataDir = "${storageDir}/sync";  # potentially a nodatacow subvolume
  servicesParentDir = "/mnt/storage/services";  # subvolume
  serviceDir = "${servicesParentDir}/syncthing";  # maybe a nodatacow subvolume
  databaseDir = "${serviceDir}/db";  # dir
  configDir = "${serviceDir}/cfg";  # dir
  keyDir = "${serviceDir}/key";  # dir
  key = "${keyDir}/key.pem";
  cert = "${keyDir}/cert.pem";

  allDirDevices = [ "cocoa" "olosapo" "quince" "sloe" "watermelon" ];
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
      in t != "receiveonly" && t != "receiveencrypted";
  } // (lib.attrsets.filterAttrs (n: _: n != "extraDevices") extraAttrs);
  mkDevice = name: extraAttrs: {
    id = deviceIDs.${name};
    allowedNetworks = [ "!192.168.99.0/24" "::/0" "0.0.0.0/0" ];  # !nebula
  } // extraAttrs;
  sendReceiveFor = nameList:
    if builtins.elem config.networking.hostName nameList
    then "sendreceive"
    else "receiveonly";
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
    guiAddress = "${configDir}/sock";
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
        carambola = mkDevice "carambola" {};
        cocoa = mkDevice "cocoa" {};
        coconut = mkDevice "coconut" {};
        fig = mkDevice "fig" {};
        olosapo = mkDevice "olosapo" {};
        quince = mkDevice "quince" {};
        sloe = mkDevice "sloe" {};
        tamarillo = mkDevice "tamarillo" {};
        watermelon = mkDevice "watermelon" {};
      };
      folders = {
        # TODO: milder/no versioning on non-servers
        "android-shared" = mkFolder "android-shared" {
          extraDevices = [ "carambola" "fig" ];
        };
        "books" = mkFolder "books" {
          extraDevices = [ "carambola" "coconut" "fig" ];
        };
        "DecSync" = mkFolder "DecSync" {
          id = "8u43w-prlse";  # TODO: reinit on next reinstall
          extraDevices = [ "carambola" "fig" ];
        };
        "Librera" = mkFolder "Librera" {
          extraDevices = [ "carambola" "coconut" "fig" ];
        };
        "camera" = mkFolder "camera" { extraDevices = [ "carambola" "fig" ]; };
        "code" = mkFolder "code" {
          type = sendReceiveFor [ "cocoa" ];
          versioning = lib.mkDefault {
            type = "staggered";
            params = {
              cleanInterval = "1800";
              maxAge = "2764800";
            };
          };
          fsWatcherDelayS = 20;
        };
        "documents" = mkFolder "documents" {
          extraDevices = [ "carambola" "fig" ];
        };
        "livestreams" = mkFolder "livestreams" {
          id = "jeiod-gytgw";  # TODO: reinit on fixing
          extraDevices = [ "carambola" "coconut" "fig" ];
          versioning = null;
        };
        "music" = mkFolder "music" {
          id = "music-dirty";
          extraDevices = [ "fig" ];
        };
        "notes" = mkFolder "notes" { extraDevices = [ "carambola" "fig" ]; };
        "system" = mkFolder "system" {
          extraDevices = [ "fig" ] ;
        };
        "tracks" = mkFolder "tracks" {
          extraDevices = [ "carambola" "tamarillo" "fig" ];
        };
        "video" = mkFolder "video" {
          extraDevices = [ "carambola" "coconut" "fig" ];
          versioning = null;
        };
        "voice" = mkFolder "voice" {
          type = sendReceiveFor [ "cocoa" ];
          extraDevices = [ "carambola" "tamarillo" "fig" ];
        };
        "voice-raw" = mkFolder "voice-raw" {
          type = sendReceiveFor [ "cocoa" ];
          extraDevices = [ "carambola" "fig" ];
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
          chattr +C "${dataDir}"  # won't happen if it's pre-created
        fi
        chown ${chowner} "${dataDir}"  # done always
        if [[ ! -e "${serviceDir}" ]]; then
          btrfs subvol create "${serviceDir}"
          chattr +C "${serviceDir}"  # won't happen if it's pre-created
        fi
        chown ${chowner} "${serviceDir}"  # done always
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
