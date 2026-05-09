{ config, pkgs, ... }:

{
  hardware.nvidia.nvidiaPersistenced = true;

  systemd.services.nvidia-power-settings = {
    description = "Set NVIDIA power limit and temperature target";
    wantedBy = [ "multi-user.target" ];
    after = [ "nvidia-persistenced.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "nvidia-power-settings" ''
        ${config.hardware.nvidia.package.bin}/bin/nvidia-smi -pl 380
        ${config.hardware.nvidia.package.bin}/bin/nvidia-smi -gtt 65
      '';
    };
  };
}
