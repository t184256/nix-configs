{ pkgs, inputs, ... }:

{
  nixpkgs.overlays = [
    (import ../../overlays/yt-dlp.nix)
    inputs.yousable.overlays.yousable
  ];
  services.yousable = {
    enable = true;
    package = pkgs.python3Packages.yousable;  # with overlays applied
    crawler.enable = true;
    downloader.enable = true;
    server.enable = false;
    configFile = "/etc/yousable/config.yaml";
  };
  systemd = {
    services.yousable-crawler = {
      requires = [ "remote-yousable.mount" ];
      after = [ "remote-yousable.mount" ];
    };
    services.yousable-downloader = {
      requires = [ "remote-yousable.mount" ];
      after = [ "remote-yousable.mount" ];
    };
    mounts = [ {
      before = [ "remote-fs.target" ];
      what = "yousable@loquat.unboiled.info:";
      where = "/remote/yousable";
      type = "fuse.sshfs";
      options = "identityfile=/mnt/persist/secrets/yousable-ssh/id_ed25519,uid=yousable,gid=yousable,allow_other";
    } ];
  };
  environment.systemPackages = with pkgs; [ sshfs ];
  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/etc/yousable";
      mode = "550";
      user = "yousable";
      group = "yousable";
    }
  ];
}
