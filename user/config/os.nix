{ lib, ... }:

{
  options.system.os = lib.mkOption {
    default = "NixOS";
    type = lib.types.enum [ "NixOS" "OtherLinux" "Nix-on-Droid" ];
  };
}
