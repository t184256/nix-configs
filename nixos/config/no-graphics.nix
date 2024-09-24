{ config, lib, ... }:

{
  options.system.noGraphics = lib.mkOption {
    default = false;
    type = lib.types.bool;
  };

  config = lib.mkMerge [
    (lib.mkIf config.system.noGraphics {
      nixpkgs.overlays = [(_: super: {
        qemu = super.qemu.override {
          alsaSupport = false;
          pulseSupport = false;
          pipewireSupport = false;
          sdlSupport = false;
          jackSupport = false;
          gtkSupport = false;
        };
      })];
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
