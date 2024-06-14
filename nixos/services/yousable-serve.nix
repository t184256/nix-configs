{ ... }:

{
  services.yousable = {
    enable = true;
    crawler.enable = false;
    downloader.enable = false;
    server = {
      enable = true;
      address = "127.0.0.1";
      port = 9696;
    };
    configFile = "/etc/yousable/config.yaml";
  };
  services.nginx = {
    enable = true;
    appendConfig = ''
        worker_processes auto;
    '';
    appendHttpConfig = ''
        sendfile_max_chunk 512k;
    '';
    virtualHosts."yousable.unboiled.info" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:9696";
      extraConfig = ''
        gzip off;
        gzip_proxied off;
        proxy_cache off;
        proxy_buffering off;
      '';
      locations."/out".root = "/mnt/persist/cache/yousable";
      locations."/out".extraConfig = ''
        autoindex off;
        internal;
      '';
    };
  };

  users.users.yousable.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBlODWQlIC3gEV0nktV45rCyQ4yqaC8BoZsUXriIU+Uc yousable@araceae"
  ];
  services.openssh.extraConfig = ''
    Match User yousable
      ForceCommand internal-sftp
      AllowTcpForwarding no
  '';

  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/etc/yousable";
      mode = "550";
      user = "yousable";
      group = "yousable";
    }
  ];
  fileSystems."/mnt/persist/cache/yousable/live" = {
    device = "/mnt/persist/home/monk/.sync/livestreams";
    options = [ "bind" ];
  };
}
