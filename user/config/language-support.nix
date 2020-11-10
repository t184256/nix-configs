{ lib, ... }:

{
  options.language-support = lib.mkOption {
    default = [];
    type = lib.types.listOf (lib.types.enum [ "nix" "python" "bash" "tex" ]);
    description = "Which languages to install tools for";
  };
}
