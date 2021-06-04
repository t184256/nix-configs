{ pkgs, lib, config, ... }:

{
  imports = [ ./config/no-graphics.nix ];
  nixpkgs.overlays = [
   (import ../overlays/iosevka-t184256.nix)
   (import ../overlays/select-google-fonts.nix)
   (import ../overlays/noto-fonts-extracondensed.nix)
  ];

  home = if config.system.noGraphics then {} else {
   packages = with pkgs; [                  # overlays:
     iosevka-t184256                        # * iosevka-t184256
     (google-fonts.just "RobotoCondensed")  # * select-google-fonts
     noto-fonts-extracondensed              # * noto-fonts-extracondensed
   ];
   file.".config/fontconfig/fonts.conf".text = ''
     <?xml version="1.0"?>
     <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
     <fontconfig>

       <!-- Only works OK with firefox if there's no regular Noto -->

       <alias>
         <family>sans-serif</family>
         <prefer><family>Noto Sans ExtraCondensed</family></prefer>
       </alias>

       <alias>
         <family>serif</family>
         <prefer><family>Noto Serif ExtraCondensed</family></prefer>
       </alias>

       <alias>
         <family>monospace</family>
         <prefer><family>Iosevka Term</family></prefer>
       </alias>

     </fontconfig>
   '';
  };
}
