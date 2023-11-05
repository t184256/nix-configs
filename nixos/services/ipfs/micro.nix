_:

{
  services.kubo.settings.Datastore = {
    StorageMax = "512M";
    GCPeriod = "30s";
    StorageGCWatermark = 50;
    Spec = { # default except for sync = false, unlocks ~8 MB/s -> ~16 MB/s
      mounts = [
        {
          child = {
            path = "blocks";
            shardFunc = "/repo/flatfs/shard/v1/next-to-last/2";
            sync = false;
            type = "flatfs";
          };
          mountpoint = "/blocks";
          prefix = "flatfs.datastore";
          type = "measure";
        }
        {
          child = {
            compression = "none";
            path = "datastore";
            type = "levelds";
          };
          mountpoint = "/";
          prefix = "leveldb.datastore";
          type = "measure";
        }
      ];
      type = "mount";
    };
  };
}
