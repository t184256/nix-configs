{
  imports = [
    ../../nixos/services/apollo.nix
  ];

  services.apollo = {
    enable = true;
    switch = {
      streaming = {
        output = "HDMI-1";
        custom-edid = true;
      };
    };
  };
}
