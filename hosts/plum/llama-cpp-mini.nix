{ pkgs, ... }:

# Qwen3.5-9B (UD-Q4_K_XL, MTP build) on a AMD Radeon RX 7600M XT 8GB eGPU, 120W

# bench-mini --think:
# target      pp      ttft   avg pp   decode tps    gen
#    256     257    0.402s      639         49.9    256
#   8192    8193    9.011s      909         47.8    256
#  16384   16385   19.065s      859         45.3    256
#  32768   32769   43.551s      752         38.8    256
#  65024   65025  107.375s      606         36.5    256

# bench-mini --nothink:
# target      pp      ttft   avg pp   decode tps    gen
#    256     260    0.380s      681         43.3    256
#   8192    8195    9.152s      895         34.1    256
#  16384   16387   18.985s      863         37.7    256
#  32768   32771   43.916s      746         30.9    256
#  65024   65027  108.386s      600         29.0    256

let
  host = "192.168.99.53";
  port = 11113;
in
{
  systemd.services.llama-cpp-mini = {
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/sys/bus/pci/devices/0000:1c:00.0/driver";

    environment.HIP_VISIBLE_DEVICES = "0";

    script = ''
      exec ${pkgs.llama-cpp-rocm-gfx1102}/bin/llama-server \
        --host ${host} \
        --port ${toString port} \
        -m ${pkgs.qwen35-9b-mtp-ud-q4kxl} \
        --alias qwen3.5-9b \
        --fit off \
        --ctx-size 65536 \
        --cache-type-k q8_0 \
        --cache-type-v q8_0 \
        --temp 0 \
        --parallel 1 \
        -b 4096 \
        -ub 512 \
        -ngl 999 \
        --flash-attn on \
        --offline \
        --spec-type draft-mtp \
        --spec-draft-n-max 6 \
        --spec-draft-p-min 0.8
    '';

    serviceConfig = {
      User = "llama-cpp";
      Group = "llama-cpp";
      PrivateDevices = false;
      PrivateTmp = true;
      ProtectHome = true;
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  users.groups."llama-cpp" = { };
  users.users."llama-cpp" = {
    isSystemUser = true;
    group = "llama-cpp";
    extraGroups = [ "video" "render" ];
  };

  networking.firewall.allowedTCPPorts = [ port ];

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "bench-mini" ''
      exec ${pkgs.llama-benchy-nice}/bin/llama-benchy-nice \
        --base-url http://${host}:${toString port}/v1 \
        --model qwen3.5-9b \
        --tokenizer qwen3.5 \
        --pp 256 8192 16384 32768 65024 \
        --tg 256 --runs 5 --no-cache \
        "$@"
    '')
  ];
}
