{ pkgs, ... }:

# Qwen3.8-27B-Q8_0 GGUF + MTP speculative decoding on plum with dual RTX 3090

let
  llama-cpp = pkgs.llama-cpp-cuda-vulkan;
  model = pkgs.qwen38-27b-q80;
  mmproj = pkgs.qwen38-27b-mmproj-f16;
  chat-template = pkgs.qwen-sharp-chat-template;
in

{
  nixpkgs.overlays = [
    (import ../../overlays/llama-cpp/default.nix)
  ];

  environment.persistence."/mnt/persist".directories = [ "/var/lib/llama-cpp" ];

  systemd.services.llama-cpp = {
    description = "llama-cpp: Qwen3.8-27B-Q8_0 + MTP";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      User = "llama-cpp";
      Group = "llama-cpp";
      Environment = [
        "LLAMA_CACHE=/var/lib/llama-cpp/cache"
        "LD_LIBRARY_PATH=/run/opengl-driver/lib"
        "GGML_CUDA_P2P=1"
      ];
      ExecStart = ''
        ${llama-cpp}/bin/llama-server \
          --cache-ram 24576 \
          --fit off \
          -c 262144 \
          -ngl 9999 \
          -fa on \
          -m ${model} \
          --chat-template-file ${chat-template} \
          --mmproj ${mmproj} \
          --image-max-tokens 16384 \
          --jinja \
          --reasoning off \
          --chat-template-kwargs '{"reasoning_effort":"medium"}' \
          --parallel 2 \
          --kv-unified \
          --reasoning-preserve \
          --device cuda0,cuda1 \
          -sm tensor \
          --device-draft cuda0,cuda1 \
          --spec-type draft-mtp \
          --spec-draft-n-max 2 \
          --temp 0.7 \
          --top-p 0.8 \
          --top-k 20 \
          --presence-penalty 1.5 \
          --min-p 0.00 \
          -ctk q8_0 \
          -ctv q8_0 \
          -ctkd q8_0 \
          -ctvd q8_0 \
          --metrics \
          --host 192.168.99.53 \
          --port 11111
      '';
      KillSignal = "SIGINT";
      TimeoutStopSec = "30s";
      PrivateDevices = false;
      PrivateTmp = true;
      ProtectHome = true;
      StateDirectory = "llama-cpp";
      Restart = "always";
      RestartSec = "10s";
    };
  };

  users.groups.llama-cpp = { };
  users.users.llama-cpp = {
    isSystemUser = true;
    group = "llama-cpp";
    extraGroups = [ "video" "render" ];
    home = "/var/lib/llama-cpp";
  };

  networking.firewall.allowedTCPPorts = [ 11111 ];
}
