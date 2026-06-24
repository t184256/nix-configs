{ pkgs, lib, ... }:

let
  llama-cpp = pkgs.llama-cpp-rocm-gfx1102;
  model   = pkgs.zeta_2_1;
  host    = "192.168.99.53";
  port    = 11113;
in
{
  systemd.services.llama-cpp-mini = {
    description = "llama-cpp-mini: zeta-2.1 on AMD RX 7600";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/sys/bus/pci/devices/0000:1c:00.0";
    environment.HIP_VISIBLE_DEVICES = "1";
    script = ''
      exec ${llama-cpp}/bin/llama-server \
        --host ${host} \
        --port ${toString port} \
        -m ${model} \
        --alias zeta-2.1 \
        --ctx-size 32768 \
        --cache-type-k q8_0 \
        --cache-type-v q8_0 \
        --temp 0 \
        --parallel 1 \
        -ngl 999 \
        --no-mmap \
        --flash-attn on \
        --offline
    '';
    serviceConfig = {
      User = "vllm";
      Group = "vllm";
      PrivateDevices = false;
      PrivateTmp = true;
      ProtectHome = true;
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
