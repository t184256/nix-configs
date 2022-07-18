{ pkgs, inputs, ... }:

let
  keyboard-remap = inputs.keyboard-remap.defaultPackage.${pkgs.system};
  keyboard-remap-service = {
    Unit = {
      Description = "keyboard-remap";
      WantedBy = [ "multi-user.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "sudo ${keyboard-remap}/bin/keyboard-remap-cz";
      Restart = "on-failure";
    };
  };
in
{
  home.packages = [ keyboard-remap ];
  systemd.user.services.keyboard-remap = keyboard-remap-service;
}
