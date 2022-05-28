{ ... }:

{
  boot.extraModulePackages = [
    (config.boot.kernelPackages.callPackage ./i915-patched.nix {})
  ];
}
