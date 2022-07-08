{ pkgs, inputs, ... }:

let
  wait-for-keypress = inputs.wait-for-keypress.defaultPackage.${pkgs.system};
  keyboard-remap = inputs.keyboard-remap.defaultPackage.${pkgs.system};
  juggler = pkgs.writeScript "keyboard-remapper-juggler" ''
    #!/bin/sh
    while true; do
      echo 'using main remapper: keyboard-remap-onemix'
      ${keyboard-remap}/bin/keyboard-remap-onemix &
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
  environment.systemPackages = [ keyboard-remap ];
  systemd.services.keyboard-remap = keyboard-remap-service;
}
