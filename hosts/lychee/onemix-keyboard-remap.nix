{ config, pkgs, ... }:

let
  keyboard-remap-onemix = pkgs.stdenv.mkDerivation {
    name = "keyboard-remap-onemix";
    nativeBuildInputs = with pkgs; [ python3 libevdev pkgconfig ];
    prapagatedBuildInputs = with pkgs; [ libevdev ];
    src = pkgs.fetchFromGitHub {
      owner = "t184256";
      repo = "keyboard-remap";
      rev = "279de48be7301b1130559372d4c38a5b5e112425";
      sha256 = "0bp8p6127wyrdi52fjk96w45wyip5c3xv9xypz0vvx8n202vvj75";
    };
    patchPhase = ''
      patchShebangs ./preprocessor.py
    '';
    compilePhase = ''
      make
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp ./keyboard-remap-onemix $out/bin/keyboard-remap-onemix
    '';
  };
  keyboard-remap-onemix-service = {
    description = "keyboard-remap-onemix";
    wantedBy = [ "multi-user.target" ];
    path = [ keyboard-remap-onemix ];

    serviceConfig = {
      Type = "simple";
      ExecStart = ''
        ${keyboard-remap-onemix}/bin/keyboard-remap-onemix
      '';
      Restart = "on-failure";
    };
  };
in
{
  environment.systemPackages = [ keyboard-remap-onemix ];
  systemd.services.keyboard-remap-onemix = keyboard-remap-onemix-service;
}
