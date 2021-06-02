{ config, pkgs, ... }:

let
  keyboard-remap-onemix = pkgs.stdenv.mkDerivation {
    name = "keyboard-remap-onemix";
    nativeBuildInputs = with pkgs; [ python3 libevdev pkgconfig ];
    prapagatedBuildInputs = with pkgs; [ libevdev ];
    src = pkgs.fetchFromGitHub {
      owner = "t184256";
      repo = "keyboard-remap";
      rev = "8c65fcb2e5672921cf43ab89c1084433eeddea58";
      sha256 = "0zq3z7nkhc2z5f61kia8w1h5pfnrn6sk5bzkf2l0mbrvh417vyfp";
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
