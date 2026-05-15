{ inputs, pkgs, ... }:

# Qwen3.6-27B AWQ + DFlash speculative decoding on plum with dual RTX 3090
# To disable DFlash: drop --speculative-config,
# set --max-num-batched-tokens 2048, drop two dflash-only VLLM_* env vars

let
  pkgsCuda = import inputs.nixpkgs {
    system = pkgs.system;
    config = { cudaSupport = true; allowUnfree = true; };
    overlays = [ (import ../../overlays/vllm) ];
  };

  vllm = pkgsCuda.vllm;
  cudatoolkit = pkgsCuda.cudaPackages.cudatoolkit;

  model = pkgs.qwen36-27b-awq;
  draft = pkgs.qwen36-27b-dflash-draft;
  # Nothink defaults (server default is enable_thinking=false).
  # Applies to bare requests only, users should override it.
  generationConfig = pkgs.writeTextDir "generation_config.json"
    (builtins.toJSON {
      temperature = 0.7; top_p = 0.8; top_k = 20; presence_penalty = 1.5;
      eos_token_id = [ 248046 248044 ];  # <|im_end|> <|endoftext|>
    });
  maxModelLen = 262144;
  maxNumSeqs = 4;
  numSpecTokens = 15;  # z-lab recommends 15 for 27B-DFlash
  # vllm reserves maxNumSeqs * (numSpecTokens - 1) draft slots inside the batch;
  # add them on top of the 2048 base so max_num_scheduled_tokens stays 2048.
  # without dflash: just use 2048 directly.
  maxNumBatchedTokens = 2048 + maxNumSeqs * (numSpecTokens - 1);
  specConfig = builtins.toJSON {
    method = "dflash";
    model = toString draft;
    num_speculative_tokens = numSpecTokens;
    draft_tensor_parallel_size = 2;
  };

  env = [
    "LD_LIBRARY_PATH=/run/opengl-driver/lib"
    "CUDA_HOME=${cudatoolkit}"
    "LIBRARY_PATH=${cudatoolkit}/lib:${cudatoolkit}/lib/stubs"
    "VLLM_NCCL_SO_PATH=${pkgsCuda.cudaPackages.nccl}/lib/libnccl.so"
    # triton writes ~/.triton; system user home is /var/empty (read-only)
    # TRITON_CACHE_DIR overrides the home lookup before it even happens
    "TRITON_CACHE_DIR=/var/lib/vllm/triton"
    # flashinfer source builds don't pre-compile cached_ops/ (sampling, renorm,
    # etc.) — only PyPI wheels do. JIT fallback is permanent; needs nvcc + c++
    "FLASHINFER_NVCC=${pkgsCuda.cudaPackages.cuda_nvcc}/bin/nvcc"
    "FLASHINFER_CACHE_DIR=/var/lib/vllm/flashinfer"
    # dflash only: reclaim 0.18 GiB from CUDA graph memory profiling (PIECEWISE)
    "VLLM_MEMORY_PROFILER_ESTIMATE_CUDAGRAPHS=0"
    # dflash only: default 394 MiB workspace OOMs at first inference (lazy alloc
    # outside profiling window); BatchDFlashPrefillWrapper creates two per group
    "VLLM_FLASHINFER_WORKSPACE_BUFFER_SIZE=${toString (64 * 1024 * 1024)}"
    "PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True"
    "SAFETENSORS_FAST_GPU=1"
    "CUDA_DEVICE_ORDER=PCI_BUS_ID"
    "OMP_NUM_THREADS=4"  # a rather random number for concurrency <=2
    #"VLLM_ENFORCE_STRICT_TOOL_CALLING=1"
  ];

  script = pkgs.writeShellScript "vllm" ''
    exec ${vllm}/bin/vllm serve ${model} \
      --generation-config ${generationConfig} \
      --kv-cache-dtype fp8 \
      --quantization awq_marlin \
      --limit-mm-per-prompt '{"image": 1, "video": 0}' \
      --speculative-config '${specConfig}' \
      --max-num-seqs ${toString maxNumSeqs} \
      --max-num-batched-tokens ${toString maxNumBatchedTokens} \
      --max-model-len ${toString maxModelLen} \
      --tensor-parallel-size 2 \
      --gpu-memory-utilization 0.95 \
      --enable-prefix-caching \
      --reasoning-parser qwen3 \
      --default-chat-template-kwargs '{"enable_thinking": false}' \
      --async-scheduling \
      --enable-auto-tool-choice --tool-call-parser qwen3_coder \
      --disable-access-log-for-endpoints /metrics \
      --served-model-name qwen3.6-27b qwen3.6-27b-think qwen3.6-27b-nothink \
      --host 192.168.99.53 --port 11111
  '';
  # Eats a bit of extra VRAM we don't have: --performance-mode interactivity
  # Frees up a bit of it: --compilation-config.max_cudagraph_capture_size=64
  # dflash: Maximum concurrency for 262,144 tokens per request: 1.17x
  # without dflash it is more like 2x that
in

{
  environment.persistence."/mnt/persist".directories = [ "/var/lib/vllm" ];

  nix.settings.extra-substituters = [ "https://cache.nixos-cuda.org" ];
  nix.settings.extra-trusted-public-keys = [
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
  ];

  systemd.services.vllm = {
    description = "vllm: Qwen3.6-27B AWQ + DFlash";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    # for flashinfer JIT
    path = with pkgs; [
      bash coreutils which ninja stdenv.cc cudaPackages.cuda_nvcc
    ];
    serviceConfig = {
      User = "vllm";
      Group = "vllm";
      Environment = env;
      ExecStart = script;
      PrivateDevices = false;
      PrivateTmp = true;
      ProtectHome = true;
      StateDirectory = "vllm";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  users.groups.vllm = { };
  users.users.vllm = {
    isSystemUser = true;
    group = "vllm";
    extraGroups = [ "video" "render" ];
    home = "/var/lib/vllm";  # compilation cache
  };

  networking.firewall.allowedTCPPorts = [ 11111 ];
}
