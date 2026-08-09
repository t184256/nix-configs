{ inputs, pkgs, ... }:

# Qwen3.6-27B AutoRound INT4 + MTP on plum with dual RTX 3090

let
  pkgsCuda = import inputs.nixpkgs {
    system = pkgs.system;
    config = { cudaSupport = true; allowUnfree = true; };
    overlays = [ (import ../../overlays/vllm) ];
  };

  vllm = pkgsCuda.vllm;
  cudatoolkit = pkgsCuda.cudaPackages.cudatoolkit;

  model = pkgs.qwen36-27b-autoround;
  # Nothink defaults (server default is enable_thinking=false).
  # Applies to bare requests only, users should override it.
  generationConfig = pkgs.writeTextDir "generation_config.json"
    (builtins.toJSON {
      temperature = 0.7; top_p = 0.8; top_k = 20; presence_penalty = 1.5;
      eos_token_id = [ 248046 248044 ];  # <|im_end|> <|endoftext|>
    });
  maxModelLen = 262144;
  maxNumSeqs = 2;
  numSpecTokens = 3;
  #maxNumBatchedTokens = 8192;
  maxNumBatchedTokens = 2048;
  specConfig = builtins.toJSON {
    method = "mtp";
    num_speculative_tokens = numSpecTokens;
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
    #"VLLM_MEMORY_PROFILER_ESTIMATE_CUDAGRAPHS=0"
    # dflash only: default 394 MiB workspace OOMs at first inference (lazy alloc
    # outside profiling window); BatchDFlashPrefillWrapper creates two per group
    #"VLLM_FLASHINFER_WORKSPACE_BUFFER_SIZE=${toString (64 * 1024 * 1024)}"
    # expandable_segments crashes on some NVLink setups (cuMemMap path) but
    # helps defragment reserved-but-unallocated memory during graph capture;
    # incompatible with OffloadingConnector (pinned KV gets invalidated by VMM)
    "PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512"
    "NCCL_P2P_LEVEL=NVL"  # pin NCCL P2P to NVLink, not PCIe
    #"NCCL_CUMEM_ENABLE=0"  # avoids cuMem unified-memory path in NCCL
    "SAFETENSORS_FAST_GPU=1"
    "CUDA_DEVICE_ORDER=PCI_BUS_ID"
    # MTP rejection-sampler path: FlashInfer sampler adds overhead without a win
    "VLLM_USE_FLASHINFER_SAMPLER=0"
    "OMP_NUM_THREADS=4"  # a rather random number for concurrency <=2
    #"VLLM_ENFORCE_STRICT_TOOL_CALLING=1"
    # deterministic block hashing across restarts (required for fs tier)
    "PYTHONHASHSEED=0"
    # can't use Model Runner v2 yet, conflicts with dflash
    #"VLLM_USE_V2_MODEL_RUNNER=1"
  ];

  # Fixes empty <think></think> spam, </thinking> hallucination, unclosed
  # think before tool call, no-user-query crash, developer role, etc.
  froggericTemplate = pkgs.fetchurl {  # qwen3.6-froggeric-v21.3 (2026-07-02)
    url = "https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates"
        + "/resolve/main/chat_template.jinja";
    hash = "sha256-0gPzNC2Kf4R03VVWPuzjom5xshxvZnyduck7dis7+Zc=";
  };

  script = pkgs.writeShellScript "vllm" ''
    exec ${vllm}/bin/vllm serve ${model} \
      --generation-config ${generationConfig} \
      --quantization auto_round \
      --language-model-only \
      --max-num-seqs ${toString maxNumSeqs} \
      --max-num-batched-tokens ${toString maxNumBatchedTokens} \
      --speculative-config '${specConfig}' \
      --tensor-parallel-size 2 \
      --gpu-memory-utilization 0.92 \
      --enable-chunked-prefill \
      --reasoning-parser qwen3 \
      --chat-template ${froggericTemplate} \
      --default-chat-template-kwargs '{"enable_thinking": false}' \
      --compilation-config '{"cudagraph_capture_sizes": [1,2,4,8,16,24,32]}' \
      --long-prefill-token-threshold 2048 \
      --enable-auto-tool-choice --tool-call-parser qwen3_coder \
      --enable-prefix-caching \
      --disable-access-log-for-endpoints /metrics \
      --served-model-name qwen3.6-27b qwen3.6-27b-think qwen3.6-27b-nothink \
      --host 192.168.99.53 --port 11111
  '';
      #--kv-cache-dtype fp8_e4m3 \
      #--async-scheduling \
      #--disable-custom-all-reduce \

      #--kv-offloading-size 12 --kv-offloading-backend native \
      #--kv-transfer-config '{"kv_connector_extra_config": {"spec_name": "TieringOffloadingSpec", "secondary_tiers": [{"type": "fs", "root_dir": "/var/lib/vllm/kv-cache"}]}}' \
  # --gpu-memory-utilization 0.82 currently uses ~ 21670MiB / 24576MiB,
  #                               leaving ~2.8 GB VRAM for desktop/GUI on GPU 0
  #                                   and ~2.8 GB VRAM for whisper.cpp on GPU 1
  # --language-model-only frees up VRAM
  # --limit-mm-per-prompt '{"image": 1, "video": 0}' is lighter alternative
  # 1,2,4,8,16,24,32 is tuned for numSpecTokens=7
  # Frees up a bit of it: --compilation-config.max_cudagraph_capture_size=64
  # dflash: Maximum concurrency for 262,144 tokens per request: 1.20x
  # without dflash it is more like 2x that
  # illegal memory access in custom_all_reduce.cuh: --disable-custom-all-reduce
in

{
  environment.persistence."/mnt/persist".directories = [ "/var/lib/vllm" ];
  # purge stale KV-cache blocks older than one day
  systemd.tmpfiles.rules = [ "x /var/lib/vllm/kv-cache  - - - 1d" ];

  nix.settings.extra-substituters = [ "https://cache.nixos-cuda.org" ];
  nix.settings.extra-trusted-public-keys = [
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
  ];

  systemd.services.vllm = {
    description = "vllm: Qwen3.6-27B AutoRound + DFlash";
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
      KillSignal = "SIGINT";
      TimeoutStopSec = "30s";
      PrivateDevices = false;
      PrivateTmp = true;
      ProtectHome = true;
      StateDirectory = "vllm";
      Restart = "always";
      RestartSec = "10s";
      TemporaryFileSystem = [ "/dev/shm:mode=1777,size=16G" ];  # auto cleanup
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
