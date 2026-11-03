{
  imports = [ ../../nixos/services/apollo.nix ];

  services.apollo = {
    enable = true;
    connector = "HDMI-A-4";
    edid.enable = false;
  };
  services.sunshine-fixer = { enable = true; output = "card4-HDMI-A-4"; };
}
