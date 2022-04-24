{ pkgs, inputs, ... }:

let
  wait-for-keypress =
    inputs.wait-for-keypress.defaultPackage.${pkgs.system};
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
  juggler = pkgs.writeScript "keyboard-remapper-juggler" ''
    #!/bin/sh
    while true; do
      echo 'using main remapper: keyboard-remap-onemix'
      ${keyboard-remap-onemix}/bin/keyboard-remap-onemix &
      pid=$!; ${wait-for-keypress} /dev/input/event5; kill $pid; wait $pid
      if [ -x /var/run/alt-keyboard-remapper ]; then
        echo "using alt remapper: $(realpath /var/run/alt-keyboard-remapper)"
        /var/run/alt-keyboard-remapper &
        pid=$!; ${wait-for-keypress} /dev/input/event5; kill $pid; wait $pid
      fi
    done
  '';

  keyboard-remap-service = {
    description = "keyboard-remap";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${juggler}";
      Restart = "on-failure";
    };
  };
in
{
  environment.systemPackages = [ keyboard-remap-onemix ];
  systemd.services.keyboard-remap = keyboard-remap-service;
}
