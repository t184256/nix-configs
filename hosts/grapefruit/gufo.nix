{ inputs, pkgs, ... }:

# TODO: run smaller models on NPU, but mind amd/xdna-driver#1605

# Qwen3.8-Flash-Next (UD-Q4_K_XL + shared-Q8 MTP), gfx1151-only:
# compared to gufo, it gains q8 KV, impressive parallelism and ROCm-FAST

# 86576M GTT / ~98G of actual usage ???

# bench-gufo --think:
# target      pp      ttft   avg pp   decode tps    gen
#    256     257    0.319s      805         52.3    606
#   8192    8193    5.250s     1561         49.5    762
#  16384   16385   10.017s     1636         54.8    526
#  32768   32769   20.581s     1592         54.0    501
#  65536   65537   41.999s     1560         50.3    561
# 131072  131073   86.455s     1516         53.1    504
# 196608  196609  132.842s     1480         55.7    476
# 260096  260097  179.823s     1446         52.2    375

# bench-gufo --nothink:
# target      pp      ttft   avg pp   decode tps    gen
#    256     259    0.338s      765         50.4    426
#   8192    8195    5.250s     1561         47.3    870
#  16384   16387    9.834s     1666         45.5   1024
#  32768   32771   20.216s     1621         46.1    813
#  65536   65539   42.132s     1556         47.4    538
# 131072  131075   86.491s     1515         44.2    977
# 196608  196611  132.714s     1481         47.0   1023
# 260096  260099  179.760s     1447         44.1    892

# bench-gufo --think --concurrency 2 (last row per size only):
# target      pp      ttft   avg pp   decode tps    gen
#    256     257    0.516s      528         35.5    556
#   8192    8193   11.228s      735         33.3    666
#  16384   16385   21.062s      784         32.4    500
#  32768   32769   43.397s      756         33.3    540
#  65536   65537   87.087s      753         35.0    540
# 131072  131073  178.811s      733         33.8    560
# 196608  196609  276.062s      712         31.3    393
# 260096  260097  373.892s      696         28.1    419

let
  gufo = inputs.mbufo.packages.x86_64-linux.default.overrideAttrs (_: prev: {
    # make unset ("auto") effort neutral, so I can leave it on auto
    postPatch = ''
      ${prev.postPatch or ""}
      substituteInPlace src/models/qwen/chat_template.cpp \
        --replace-fail 'reasoning.effort.value_or(ReasoningEffort::kXHigh)' \
                       'reasoning.effort.value_or(ReasoningEffort::kMedium)'

      # v0.27 gufo_core_gemm includes <hipblas/hipblas.h> through hip_utils.hpp
      # but links only hip::host and roc::hipblaslt. fix for splti ROCM outputs:
      substituteInPlace CMakeLists.txt \
        --replace-fail 'hip::host roc::hipblaslt)' \
                       'hip::host roc::hipblas roc::hipblaslt)'
    '';
  });
  gufoServe = inputs.mbufo.lib.mkGufoServe {
    system = "x86_64-linux";
    inherit gufo;
    modality = "llm";
    host = "192.168.99.52";
    port = 11111;
#   model =
#     "${pkgs.qwen38-flash-next-ud-q4kxl}/" +
#     "Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf";
    model = pkgs.qwen38-flash-next-rocmfp4-fast-v2-repacked;
    mtpModel = pkgs.qwen38-flash-next-mtp-q80-agentionai;
    servedModelName = "qwen3.8-flash-next";
    context = 262144;
    speculative = "mtp";
    sessions = 2;

    extraArgs = [
      "--mmproj" "${pkgs.qwen38-flash-next-mmproj-bf16}"
      "--kv-quant" "q8"
    ];

    # no explicit sampling options: gufo auto-selects for thinking on and off

    # persists every 2k! writes scale as N^2 with context! 300 GB per convo!
    # basically needs sparser spacing a HDD, and a size cap to become viable
    #cacheDisk = "/var/lib/gufo";
    #cacheDiskStagingBytes = 4 * 1024 * 1024 * 1024;  # cap at ~128k context
    #cacheDiskBytes = 17 * 1024 * 1024 * 1024;  # ~4 snapshots
    # TODO: wait for a saner cache implementation, offload to RAM/HDD over LAN
  };
in
{
  users.groups.gufo = { };
  users.users.gufo = {
    isSystemUser = true;
    group = "gufo";
    extraGroups = [ "video" "render" ];
  };

  systemd.services.gufo = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      User = "gufo";
      Group = "gufo";
      Restart = "on-failure";
      RestartSec = "30s";
      MemorySwapMax = 0;  # let's just not
      Environment = [
        "GUFO_KV_WMMA=1"  # close-to-gufo prefill speed
        # GUFO_KV_I8=2 is the default
        # TODO: test reverts below
        "GUFO_MIXED_MTP=0" "GUFO_VERIFY_BATCH_ROWS=8"
      ];
      ExecStart = [ gufoServe ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 11111 ];

  # bench-gufo [--think|--nothink] [llama-benchy args...]
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "bench-gufo" ''
      exec ${pkgs.llama-benchy-nice}/bin/llama-benchy-nice \
        --base-url http://192.168.99.52:11111/v1 \
        --model qwen3.8-flash-next \
        --tokenizer qwen3.8 \
        --pp 256 8192 16384 32768 65536 131072 196608 260096 \
        --tg 1024 --runs 5 --no-cache \
        --no-exact-tg \
        "$@"
    '')
  ];

  #environment.persistence."/mnt/persist".directories = [
  #  { directory = "/var/lib/gufo"; user = "gufo"; group = "gufo"; }
  #];
}
