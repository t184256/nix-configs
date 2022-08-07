self: super:
{
  iosevka-t184256 = (super.iosevka.overrideAttrs (_: {
    # temporary
    src = super.fetchFromGitHub {
      owner = "be5invis";
      repo = "iosevka";
      rev = "v15.6.3";
      sha256 = "sha256-wsFx5sD1CjQTcmwpLSt97OYFI8GtVH54uvKQLU1fWTg=";
    };
  })).override {
    set = "t184256";
    privateBuildPlan = {
      family = "Iosevka Term";
      spacing = "term";
      no-ligation = "true";

      variants = {
        # TODO: try something closer to Ubuntu Mono style?
        inherits = "ss20";  # default to curly style
        design = {
          capital-a = "curly-serifless";
          capital-g = "toothless-corner-serifless-hooked";
          capital-k = "curly-serifless";
          capital-r = "curly";
          capital-q = "straight";
          capital-v = "curly";
          capital-w = "curly";
          capital-x = "curly-serifless";
          capital-y = "curly-serifless";
          capital-z = "curly-serifless";
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
          #cyrl-capital-zhe = "curly";
          cyrl-capital-ka = "curly-serifless";
          cyrl-capital-u = "curly";
          cyrl-capital-ya = "curly";
          cyrl-ka = "curly-serifless";
          #cyrl-zhe = "curly";
          #cyrl-u = "curly";
          cyrl-ya = "curly";
          at = "fourfold-solid-inner";
          asterisk = "penta-low";
          brace = "straight";
          bar = "force-upright";
          dollar = "open";
          cent = "open";
          percent = "dots";
          zero = "slashed";
          #four = "semi-open-no-crossing";
          six = "open-contour";
          seven = "curly-serifless";
          nine = "open-contour";
        };
        # italic seems largely fine
      };

      # less weights => faster rebuilding
      weights = {
        extralight = { css = 200; menu = 200; shape = 200; };
        light = { css = 300; menu = 300; shape = 300; };
        regular = { css = 400; menu = 400; shape = 400; };
        medium = { css = 500; menu = 500; shape = 500; };
        semibold = { css = 600; menu = 600; shape = 600; };
        bold = { css = 700; menu = 700; shape = 700; };
      };

      # compress letters, default is 500
      widths.normal = { css = "normal"; menu = 5; shape = 434; };

      # move lines closer to each other, default is 1250
      metric-override.leading = 1000;
    };
  };
}
