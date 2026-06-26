{ lib, ... }:

{
  options.roles.mua = lib.mkOption {
    default = false;
    type = lib.types.bool;
  };

  options.roles.slop = lib.mkOption {
    default = false;
    type = lib.types.bool;
    description = ''
      Enable genAI tooling that bloats closure and requires credentials.
    '';
  };
}
