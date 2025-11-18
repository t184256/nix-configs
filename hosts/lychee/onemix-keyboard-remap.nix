{ pkgs, inputs, ... }:

let
  input-utils = inputs.input-utils.defaultPackage.${pkgs.stdenv.hostPlatform.system};
  keyboard-remap = inputs.keyboard-remap.defaultPackage.${pkgs.stdenv.hostPlatform.system};
  juggler = pkgs.writeScript "keyboard-remapper-juggler" ''
    #!/bin/sh
    while true; do
      echo 'using main remapper: keyboard-remap-onemix'
      ${keyboard-remap}/bin/keyboard-remap-onemix &
      pid=$!
      mic=$(${input-utils}/bin/find-input-device 'HDA Intel PCH Mic')
      ${input-utils}/bin/wait-for-keypress "$mic"
      kill $pid; wait $pid
      if [ -x /var/run/alt-keyboard-remapper ]; then
        echo "using alt remapper: $(realpath /var/run/alt-keyboard-remapper)"
        /var/run/alt-keyboard-remapper &
        pid=$!
        ${input-utils}/bin/wait-for-keypress "$mic"
        kill $pid; wait $pid
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
  environment.systemPackages = [ keyboard-remap ];
  systemd.services.keyboard-remap = keyboard-remap-service;
}
