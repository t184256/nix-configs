self: super:
{
  iosevka-t184256 = super.iosevka.override {
    set = "t184256";
    privateBuildPlan = {
      family = "Iosevka Term";
      spacing = "term";
      no-ligation = "true";

      variants = {
        # TODO: try something closer to Ubuntu Mono style?
        inherits = "ss20";  # default to curly style
        design = {
          a = "single-storey-earless-corner-serifless";
          b = "toothless-corner";
          d = "toothless-corner-serifless";
          f = "flat-hook";
          g = "single-storey-earless-corner-flat-hook";
          i = "zshaped";
          j = "flat-hook-serifed";
          k = "curly-serifless";
          l = "zshaped";
          m = "earless-corner-double-arch";
          n = "earless-corner-straight";
          p = "earless-corner";
          q = "earless-corner";
          r = "earless-corner";
          t = "flat-hook";
          u = "toothless-corner";
          v = "curly";
          w = "curly";
          x = "curly-serifless";
          y = "curly";
          z = "curly-serifless";
          asterisk = "penta-low";
          brace = "straight";
          dollar = "open";
          percent = "dots";
          # TODO: capitals, cyrillics, digits...
        };
        # TODO: italic
      };

      # less weights => faster rebuilding
      weights = {
        regular = { css = 400; menu = 400; shape = 400; };
        medium = { css = 500; menu = 500; shape = 500; };
        bold = { css = 700; menu = 700; shape = 700; };
      };

      # compress letters, default is 500
      widths.normal = { css = "normal"; menu = 5; shape = 434; };

      # move lines closer to each other, default is 1250
      metric-override.leading = 1000;
    };
  };
}
