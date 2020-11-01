{ pkgs, config, ... }:

{
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    iosevka-t184256                     # overlay: iosevka-t184256
    google-fonts.just.RobotoCondensed   # overlay: select-google-fonts
    noto-fonts-extracondensed           # overlay: noto-fonts-extracondensed
  ];
  home.file.".config/fontconfig/fonts.conf".text = ''
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
}
