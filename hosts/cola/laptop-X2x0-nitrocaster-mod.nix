{ config, pkgs, ... }:

{
  services.xserver.dpi = 176;
  boot.kernelPatches = [
    {
      name = "nitrocaster-mod-patch";
      patch = ./laptop-X2x0-nitrocaster-mod-new.patch;
    }
  ];
}
