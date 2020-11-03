{ lib, ... }:

{
  options.language-support = lib.mkOption {
    default = [];
    type = lib.types.listOf (lib.types.enum [ "bash" "python" ]);
    description = "Which languages to install tools for";
  };
}
