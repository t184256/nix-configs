{ config, pkgs, ... }:

let
  keyboard-remap-onemix = pkgs.stdenv.mkDerivation {
    name = "keyboard-remap-onemix";
    nativeBuildInputs = with pkgs; [ python3 libevdev pkgconfig ];
    prapagatedBuildInputs = with pkgs; [ libevdev ];
    src = pkgs.fetchFromGitHub {
      owner = "t184256";
      repo = "keyboard-remap";
      rev = "5e866ca78a57623790e630cbc59be5b1fd66f98b";
      sha256 = "0ivf5zfbszn3spa07sd4dvsz8f8w0mn3qzbmb8ckmd0aczrd893i";
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
