{ config, pkgs, ... }:

let
  keyboard-remap-onemix = pkgs.stdenv.mkDerivation {
    name = "keyboard-remap-onemix";
    nativeBuildInputs = with pkgs; [ python3 libevdev pkgconfig ];
    prapagatedBuildInputs = with pkgs; [ libevdev ];
    src = pkgs.fetchFromGitHub {
      owner = "t184256";
      repo = "keyboard-remap";
      rev = "eb543e6e6f2707ca7f2dc14233215f512b900173";
      sha256 = "sha256-LILmN+R+c0+AiGejl2SYzfRUY4WLt45yeCH46Jurlpk=";
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
