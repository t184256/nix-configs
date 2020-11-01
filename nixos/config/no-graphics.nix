{ config, lib, ... }:

{
  options.system.noGraphics = lib.mkOption {
    default = false;
    type = lib.types.bool;
  };

  config = lib.mkMerge [
    (lib.mkIf config.system.noGraphics {
      environment.noXlibs = true;
    })
    (lib.mkIf (! config.system.noGraphics) {
      # prevent overriding the user-selected ones
      fonts.fontconfig.defaultFonts = {
        serif = [];
        sansSerif = [];
        monospace = [];
      };
    })
  ];
}
