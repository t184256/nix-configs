{
  imports = [
    ../../nixos/services/apollo.nix
  ];

  services.apollo = {
    enable = true;
    connector = "HDMI-A-1";
    edid.enable = true;
  };
}
