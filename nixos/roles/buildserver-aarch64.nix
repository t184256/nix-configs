{ lib, pkgs, config, ... }:

with lib;

let
  qemu-aarch64-static = pkgs.stdenv.mkDerivation {
    name = "qemu-aarch64-static";

    src = builtins.fetchurl {
      url = "https://github.com/multiarch/qemu-user-static/releases/download/v5.1.0-7/qemu-aarch64-static";
      sha256 = "0yzlrlknslvas58msrbbq3hazphyydrbaqrd840bd1c7vc9lcrh6";
    };

    dontUnpack = true;
    installPhase = "install -D -m 0755 $src $out/bin/qemu-aarch64-static";
  };

  cfg = config.system.role.buildserver-aarch64;
in {
  options = {
    system.role.buildserver-aarch64.enable = mkOption {
      default = false;
      example = true;
      description = ''
        Enable what's required to act as a build server
        for a Nix-on-Droid aarch64 device.
        https://github.com/t184256/nix-on-droid/wiki/Simple-remote-building
      '';
      type = types.bool;
    };
  };

  config = mkIf cfg.enable {
    boot.binfmt.registrations.aarch64 = {
      interpreter = "${qemu-aarch64-static}/bin/qemu-aarch64-static";
      magicOrExtension = ''\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00'';
      mask = ''\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\x00\xff\xfe\xff\xff\xff'';
    };
    nix.extraOptions = ''
      extra-platforms = aarch64-linux
      trusted-users = monk
      # FIXME: wait for https://github.com/NixOS/nixpkgs/pull/103137
      #        and use nix.sandboxPaths below
      sandbox-paths = /bin/sh=${pkgs.busybox-sandbox-shell}/bin/busybox /run/binfmt/aarch64=${qemu-aarch64-static}/bin/qemu-aarch64-static
    '';
    #nix.sandboxPaths = [ "/run/binfmt/aarch64=${qemu-aarch64-static}/bin/qemu-aarch64-static" ];
  };
}
