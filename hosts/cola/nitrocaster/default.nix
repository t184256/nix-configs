{ pkgs, config, ... }:

{
  boot.kernelPackages = pkgs.linuxPackages_5_18;
  boot.extraModulePackages = [
    (config.boot.kernelPackages.callPackage ./i915-patched.nix {})
  ];
  services.xserver.dpi = 176;
}
