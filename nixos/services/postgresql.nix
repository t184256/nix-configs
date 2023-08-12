{ config, ... }:

{
  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/var/lib/postgresql";
      user = "postgres"; group = "postgres";
    }
    {
      directory = "/var/backup/postgresql";
      user = "postgres"; group = "postgres";
    }
  ];
  services.postgresqlBackup = {
    enable = config.services.postgresql.enable;
    compression = "zstd";
    compressionLevel = 12;
    startAt = "*-*-* 04:52:00";
  };
}
