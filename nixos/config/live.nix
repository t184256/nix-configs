{ config, lib, ... }:

{
  options.system.live = lib.mkOption {
    default = false;
    type = lib.types.bool;
  };

  # override some weirdness in installer profiles
  config = lib.mkIf config.system.live {
    networking.wireless.enable = false;
    networking.networkmanager.enable = true;
  };
}
