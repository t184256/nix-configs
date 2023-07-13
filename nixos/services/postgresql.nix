{ ... }:

{
  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/var/lib/postgresql";
      user = "postgres"; group = "postgres";
    }
  ];
}
