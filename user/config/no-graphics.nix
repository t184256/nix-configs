{ config, lib, ... }:

{
  imports = [ ./os.nix ];

  options.system.noGraphics = lib.mkOption {
    default = config.system.os == "Nix-on-Droid";
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
