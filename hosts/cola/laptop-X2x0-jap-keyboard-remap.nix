{ config, pkgs, ... }:

let
  keyboard-remap-jap = pkgs.stdenv.mkDerivation {
    name = "keyboard-remap-jap";
    nativeBuildInputs = with pkgs; [ python3Minimal libevdev pkgconfig ];
    prapagatedBuildInputs = with pkgs; [ libevdev ];
    src = pkgs.fetchFromGitHub {
      owner = "t184256";
      repo = "keyboard-remap";
      rev = "45238756aa4914e10342839b7e6737b08f8dbf1";
      sha256 = "0wfc376k9pdvqkhlp8gx4il755bkr5pzvzbvlmgn47yxpzlq4cf1";
    };
    patchPhase = ''
      patchShebangs ./preprocessor.py
    '';
    compilePhase = ''
      make
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp ./keyboard-remap-jap $out/bin/keyboard-remap-jap
    '';
  };
  keyboard-remap-jap-service = {
    description = "keyboard-remap-jap";
    wantedBy = [ "multi-user.target" ];
    path = [ keyboard-remap-jap ];

    serviceConfig = {
      Type = "simple";
      ExecStart = ''
        ${keyboard-remap-jap}/bin/keyboard-remap-jap
      '';
      Restart = "on-failure";
    };
  };
in
{
  environment.systemPackages = [ keyboard-remap-jap ];
  systemd.services.keyboard-remap-jap = keyboard-remap-jap-service;
}
