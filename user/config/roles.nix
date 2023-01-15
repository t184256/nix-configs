{ lib, ... }:

{
  options.roles.mua = lib.mkOption {
    default = false;
    type = lib.types.bool;
  };
}
