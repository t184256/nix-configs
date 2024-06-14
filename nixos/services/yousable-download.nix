{ ... }:

{
  services.yousable = {
    enable = true;
    crawler.enable = true;
    downloader.enable = true;
    server.enable = false;
    configFile = "/etc/yousable/config.yaml";
  };
  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/etc/yousable";
      mode = "550";
      user = "yousable";
      group = "yousable";
    }
  ];
}
