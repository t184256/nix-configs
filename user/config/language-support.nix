{ lib, ... }:

{
  options.language-support = lib.mkOption {
    default = [];
    type = lib.types.listOf lib.types.str;
    description = "Which languages to install tools for";
  };
}
