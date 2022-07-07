{ lib, ... }:

{
  options.system.live = lib.mkOption {
    default = false;
    type = lib.types.bool;
  };
}
