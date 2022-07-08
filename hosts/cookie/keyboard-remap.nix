{ pkgs, inputs, ... }:

let
  keyboard-remap = inputs.keyboard-remap.defaultPackage.${pkgs.system};
  keyboard-remap-service = {
    description = "keyboard-remap";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${keyboard-remap}/bin/keyboard-remap";
      Restart = "on-failure";
    };
  };
in
{
  environment.systemPackages = [ keyboard-remap ];
  systemd.services.keyboard-remap = keyboard-remap-service;
}
