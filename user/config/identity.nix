{ lib, ... }:

{
  options.identity.email = lib.mkOption {
    default = "monk@unboiled.info";
    type = lib.types.str;
  };
}
