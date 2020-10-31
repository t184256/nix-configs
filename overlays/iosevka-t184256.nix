self: super:
{
  iosevka-t184256 = super.iosevka.override {
    set = "t184256";
    privateBuildPlan = {
      family = "Iosevka Term";
      snapshotFamily = "iosevka";

      design = [
        "sp-fixed"  # sp-force-monospace + no-ligation
        "ss20"  # default to curly style
        "v-i-zshaped"
        "v-l-zshaped"
        "v-a-singlestorey"  # TODO: try "v-a-singlestorey-earless-corner" with next update
        # TODO: try "v-b-toothless-corner" with next update
        # TODO: try "v-d-toothless-corner" with next update
        "v-g-singlestorey" # TODO: try "v-g-earless-corner" with next update
        "v-j-straight"
        "v-k-curly"
        # TODO: try "v-p-toothless-corner" with next update
        # TODO: try "v-q-toothless-corner" with next update
        "v-asterisk-low"
        # TODO: try "v-at-long" with next update
        "v-brace-straight"
        "v-dollar-open"
        "v-percent-dots"
      ];

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
