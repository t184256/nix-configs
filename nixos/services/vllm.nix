{ inputs, pkgs, lib, ... }:

# Two manually-started services for comparing 9B with and without DFlash.
# They conflict — only one can run at a time (VRAM constraint).
#
#   systemctl start vllm          # plain AWQ
#   systemctl start vllm-dflash   # AWQ + DFlash speculation
# Both on port 8001 — they conflict so only one runs at a time.
#
# DFlash requires vllm nightly for "method":"dflash" in speculative-config.
# nixpkgs ships 0.16.0 which may lack it; overlays/vllm/ will override
# when needed. The plain service works with 0.16.0 regardless.
#
# 27B + DFlash 27B draft doesn't fit (23.6 GiB total, 0.4 GiB leftover).
# Revisit when a second GPU arrives (TP=2 is what QuantTrio recommends).

let
  pkgsCuda = import inputs.nixpkgs {
    system = pkgs.system;
    config = { cudaSupport = true; allowUnfree = true; };
    overlays = [ (import ../../overlays/vllm) ];
  };

  vllm = pkgsCuda.vllm;
  model = pkgs.qwen35-9b-awq;
  draft = pkgs.qwen35-9b-dflash-draft;

  maxModelLen      = 262144;  # model's max_position_embeddings; plain fits
  maxModelLenDFlash = 92160;  # draft model eats KV headroom; vllm reports max 95312, use 90k
  numSpecTokens = 3;

  specConfig = builtins.toJSON {
    method = "dflash";
    model = toString draft;
    num_speculative_tokens = numSpecTokens;
  };

  commonEnv = [
    "LD_LIBRARY_PATH=/run/opengl-driver/lib"
    "VLLM_NCCL_SO_PATH=${pkgsCuda.cudaPackages.nccl}/lib/libnccl.so"
    # triton writes ~/.triton; system user home is /var/empty (read-only).
    # TRITON_CACHE_DIR overrides the home lookup before it even happens.
    "TRITON_CACHE_DIR=/var/lib/vllm/triton"
  ];

  # TODO: awq_marlin? smaller kv quants? that other model quant?
  plainScript = pkgs.writeShellScript "vllm-plain" ''
    exec ${vllm}/bin/vllm serve ${model} \
      --quantization awq_marlin --kv-cache-dtype float16 \
      --max-model-len ${toString maxModelLen} \
      --gpu-memory-utilization 0.95 \
      --host 127.0.0.1 --port 8001
  '';

  # "method":"dflash" requires vllm nightly; falls back gracefully to
  # standard speculative decoding if the method isn't recognised.
  # --trust-remote-code needed if vllm loads dflash.py for the draft model.
  # Try dropping it first — nightly may load the draft model natively.
  #
  # To try GGUF instead of AWQ for the main model:
  #   replace `model` with e.g. pkgs.qwen35-27b-q4kxl (once it fits)
  #   add --tokenizer Qwen/Qwen3.5-27B-Instruct and --quantization gguf
  dflashScript = pkgs.writeShellScript "vllm-dflash" ''
    exec ${vllm}/bin/vllm serve ${model} \
      --quantization awq_marlin --kv-cache-dtype float16 \
      --dtype float16 \
      --speculative-config '${specConfig}' \
      --attention-backend flash_attn \
      --max-num-seqs 4 \
      --max-num-batched-tokens 4096 \
      --max-model-len ${toString maxModelLenDFlash} \
      --gpu-memory-utilization 0.95 \
      --trust-remote-code \
      --host 127.0.0.1 --port 8001
  '';

  commonService = {
    after = [ "multi-user.target" ];
    serviceConfig = {
      User = "vllm";
      Group = "vllm";
      Environment = commonEnv;
      PrivateDevices = false;
      PrivateTmp = true;
      ProtectHome = true;
      StateDirectory = "vllm";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

in

{
  environment.persistence."/mnt/persist".directories = [ "/var/lib/vllm" ];

  nix.settings.extra-substituters = [
    "https://cache.nixos-cuda.org"
  ];
  nix.settings.extra-trusted-public-keys = [
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
  ];

  systemd.services.vllm = lib.recursiveUpdate commonService {
    description = "vllm: Qwen3.5-9B AWQ (plain)";
    unitConfig.Conflicts = "vllm-dflash.service";
    serviceConfig.ExecStart = plainScript;
  };

  systemd.services.vllm-dflash = lib.recursiveUpdate commonService {
    description = "vllm: Qwen3.5-9B AWQ + DFlash speculative decoding";
    unitConfig.Conflicts = "vllm.service";
    serviceConfig.ExecStart = dflashScript;
  };

  users.groups.vllm = { };
  users.users.vllm = {
    isSystemUser = true;
    group = "vllm";
    extraGroups = [ "video" "render" ];
    home = "/var/lib/vllm";  # systemd reads this; sets HOME before triton init
  };

  networking.firewall.allowedTCPPorts = [ 8001 ];
}
