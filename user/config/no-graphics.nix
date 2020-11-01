{ config, lib, ... }:

{
  options.system.noGraphics = lib.mkOption {
    default = false;
    type = lib.types.bool;
  };

  config = lib.mkMerge [
    (lib.mkIf config.system.noGraphics {
      fonts.fontconfig.enable = false;
    })
    (lib.mkIf (! config.system.noGraphics) {
      fonts.fontconfig.enable = true;
    })
  ];
}
