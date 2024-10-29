{ pkgs, lib, config, inputs, ... }:

{
  imports = [ ./config/no-graphics.nix ./config/os.nix ./wraplings.nix ];
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
    file.".config/fontconfig/no-system-fonts.conf" =
      lib.mkIf (config.system.os == "OtherLinux") { text = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
          <match target="font">
            <edit mode="assign" name="autohint" >
              <bool>false</bool>
            </edit>
            <edit mode="assign" name="hinting" >
              <bool>true</bool>
            </edit>
            <edit mode="assign" name="hintstyle">
              <const>hintfull</const>
            </edit>
            <edit name="rgba" mode="assign">
              <const>none</const>
            </edit>
            <edit name="antialias" mode="assign">
              <bool>true</bool>
            </edit>
            <edit mode="assign" name="lcdfilter" >
                <const>lcddefault</const>
            </edit>
          </match>

          <include ignore_missing="yes">/etc/fonts/conf.d</include>
          <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
          <include ignore_missing="yes" prefix="xdg">fontconfig/conf.d</include>
          <include ignore_missing="yes" prefix="xdg">fontconfig/fonts.conf</include>
          <cachedir>/home/asosedki/.cache/no-system-fonts</cachedir>
          <rejectfont>
            <glob>/usr/share/fonts/*</glob>
          </rejectfont>
        </fontconfig>
      '';};
      wraplings = lib.mkIf (config.system.os == "OtherLinux") {
        no-system-fonts =
          "env FONTCONFIG_FILE=~/.config/fontconfig/no-system-fonts.conf";
    };
  };
}
