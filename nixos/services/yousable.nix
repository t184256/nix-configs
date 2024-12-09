{ pkgs, inputs, ... }:

let
  cred = "config:/mnt/storage/secrets/yousable";
  svcExtra = { serviceConfig = { Type = "exec"; LoadCredential = cred; }; };
  svcList = [
    "yousable-crawler.service"
    "yousable-downloader.service"
    "yousable-server.service"
  ];
in
{
  nixpkgs.overlays = [
    (import ../../overlays/yt-dlp.nix)
    inputs.yousable.overlays.yousable
  ];
  services.yousable = {
    enable = true;
    package = pkgs.python3Packages.yousable;  # with overlays applied
    configFile = "/run/credentials/yousable-server.service/config";
    server = {
      address = "127.0.0.1";
      port = 9696;
    };
  };
  systemd.services = {
    yousable-crawler = svcExtra;
    yousable-downloader = svcExtra;
    yousable-server = svcExtra;

    yousable-preconfigure = {
      requires = [ "mnt-storage.mount" ];
      after = [ "mnt-storage.mount" ];
      requiredBy = svcList;
      before = svcList;
      partOf = svcList;
      bindsTo = svcList;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = with pkgs; [ coreutils acl btrfs-progs e2fsprogs util-linux ];
      script = ''
        set -Eeuxo pipefail; shopt -s inherit_errexit
        mountpoint -q /mnt/storage
        if [[ ! -e "/mnt/storage/services/yousable" ]]; then
          btrfs subvol create "/mnt/storage/services/yousable"
          chown yousable:yousable "/mnt/storage/services/yousable"
          chattr +C "/mnt/storage/services/yousable"
        fi
        setfacl -m user:yousable:r-x /mnt/storage/sync
        setfacl -R -m user:yousable:rwx /mnt/storage/sync/livestreams
      '';
    };
  };

  #services.nginx = {
  #  enable = true;
  #  appendConfig = ''
  #      worker_processes auto;
  #  '';
  #  appendHttpConfig = ''
  #      sendfile_max_chunk 512k;
  #  '';
  #  virtualHosts."yousable.unboiled.info" = {
  #    enableACME = true;
  #    forceSSL = true;
  #    locations."/".proxyPass = "http://127.0.0.1:9696";
  #    extraConfig = ''
  #      gzip off;
  #      gzip_proxied off;
  #      proxy_cache off;
  #      proxy_buffering off;
  #    '';
  #    locations."/out".root = "/mnt/persist/cache/yousable";
  #    locations."/out".extraConfig = ''
  #      autoindex off;
  #      internal;
  #    '';
  #  };
  #};
}
