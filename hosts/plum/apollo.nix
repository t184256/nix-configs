_:

{
  imports = [ ../../nixos/services/apollo.nix ];

  services.apollo = {
    enable = true;
    switch = {
      enable = true;
      streaming = {
        output = "DP-5";
        force-mode = "3840x2160@60.000";
        custom-edid = false;
      };
      display = {
        output = "HDMI-2";
        force-mode = "3840x2160@120.000";
      };
      lock-session = true;
      mask-bluetooth = true;
    };
  };

  services.sunshine-fixer = { enable = true; output = "card3-DP-5"; };
}
