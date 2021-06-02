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
          a = "single-storey-earless-corner";
          b = "toothless-corner";
          d = "toothless-corner";
          g = "single-storey";
          i = "zshaped";
          j = "serifed";
          k = "curly";
          l = "zshaped";
          p = "earless-corner";
          q = "earless-corner";
          u = "toothless-corner";
          asterisk = "low";
          brace = "straight";
          dollar = "open";
          percent = "dots";
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
