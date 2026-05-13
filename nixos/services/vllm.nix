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
# plain: 256K/?x concurrency  dflash: 256K/~1x concurrency

let
  pkgsCuda = import inputs.nixpkgs {
    system = pkgs.system;
    config = { cudaSupport = true; allowUnfree = true; };
    overlays = [ (import ../../overlays/vllm) ];
  };

  vllm = pkgsCuda.vllm;
  cudatoolkit = pkgsCuda.cudaPackages.cudatoolkit;

  # 9B config
  # model = pkgs.qwen35-9b-awq;
  # draft = pkgs.qwen35-9b-dflash-draft;
  # maxModelLen = 262144;

  # 27B config (current)
  model = pkgs.qwen36-27b-awq;
  draft = pkgs.qwen36-27b-dflash-draft;
  maxModelLen      = 262144;
  #maxModelLen      = 131072;
  #maxModelLen      = 65536;
  maxModelLenDFlash = 262144;
  numSpecTokens = 5;  # z-lab recommended 15 for 27B-DFlash (block_size - 1)

  specConfig = builtins.toJSON {
    method = "dflash";
    model = toString draft;
    num_speculative_tokens = numSpecTokens;
    draft_tensor_parallel_size = 2;
  };

  commonEnv = [
    "LD_LIBRARY_PATH=/run/opengl-driver/lib"
    "VLLM_NCCL_SO_PATH=${pkgsCuda.cudaPackages.nccl}/lib/libnccl.so"
    # triton writes ~/.triton; system user home is /var/empty (read-only).
    # TRITON_CACHE_DIR overrides the home lookup before it even happens.
    "TRITON_CACHE_DIR=/var/lib/vllm/triton"
    # flashinfer source builds don't pre-compile cached_ops/ (sampling, renorm,
    # etc.) — only PyPI wheels do. JIT fallback is permanent; needs nvcc + c++.
    "FLASHINFER_NVCC=${pkgsCuda.cudaPackages.cuda_nvcc}/bin/nvcc"
    "FLASHINFER_CACHE_DIR=/var/lib/vllm/flashinfer"
    "CUDA_HOME=${cudatoolkit}"
    "LIBRARY_PATH=${cudatoolkit}/lib:${cudatoolkit}/lib/stubs"
    # 12 vCPUs / 2 TP workers = 6 per worker, rounding down to 4
    "OMP_NUM_THREADS=4"
  ];

  dflashEnv = commonEnv ++ [
    # reclaims 0.18 GiB used by CUDA graph memory profiling (PIECEWISE mode)
    "VLLM_MEMORY_PROFILER_ESTIMATE_CUDAGRAPHS=0"
    # default workspace is 394 MiB, allocated lazily at first inference (OOM).
    # 64 MiB is plenty for max_num_batched_tokens=2048; BatchDFlashPrefillWrapper
    # creates two of these (context + new_tokens), so 128 MiB total per group.
    "VLLM_FLASHINFER_WORKSPACE_BUFFER_SIZE=${toString (64 * 1024 * 1024)}"
  ];

  plainScript = pkgs.writeShellScript "vllm-plain" ''
    exec ${vllm}/bin/vllm serve ${model} \
      --quantization awq_marlin --kv-cache-dtype fp8 \
      --limit-mm-per-prompt '{"image": 1, "video": 0}' \
      --max-model-len ${toString maxModelLen} \
      --max-num-seqs 4 \
      --max-num-batched-tokens 2048 \
      --tensor-parallel-size 2 \
      --gpu-memory-utilization 0.95 \
      --enable-prefix-caching \
      --host 127.0.0.1 --port 8001
  '';
  # fp8 65K:  Maximum concurrency for 65,536 tokens: 8.85x  (10.17 GiB KV pool)
  # fp8 262K: Maximum concurrency for 262,144 tokens: 1.51x

  # To try GGUF instead of AWQ for the main model:
  #   replace `model` with e.g. pkgs.qwen35-27b-q4kxl (once it fits)
  #   add --tokenizer Qwen/Qwen3.5-27B-Instruct and --quantization gguf
  dflashScript = pkgs.writeShellScript "vllm-dflash" ''
    exec ${vllm}/bin/vllm serve ${model} \
      --quantization awq_marlin --kv-cache-dtype fp8 \
      --limit-mm-per-prompt '{"image": 1, "video": 0}' \
      --speculative-config '${specConfig}' \
      --max-num-seqs 4 \
      --max-num-batched-tokens 2080 \
      --max-model-len ${toString maxModelLenDFlash} \
      --tensor-parallel-size 2 \
      --gpu-memory-utilization 0.95 \
      --enable-prefix-caching \
      --host 127.0.0.1 --port 8001
  '';

  commonService = {
    # for flashinfer JIT
    path = with pkgs;
      [ bash coreutils which ninja stdenv.cc cudaPackages.cuda_nvcc ];
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
    serviceConfig.Environment = dflashEnv;
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
