{ lib, ... }:

{
  options.neovim.fat = lib.mkOption {
    default = false;
    type = lib.types.bool;
    description = ''
      Have a feature-packed neovim.
    '';
  };
}
