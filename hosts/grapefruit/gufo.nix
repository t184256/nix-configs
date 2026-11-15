{ inputs, pkgs, ... }:

# Qwen3.8-Flash-Next (UD-Q4_K_XL + shared-Q8 MTP), gfx1151-only:
# compared to gufo, it gains q8 and impressive parallelism

# 96480M GTT / 110G of actual usage

# bench-gufo --think:
# target      pp      ttft   avg pp   decode tps    gen
#    256     257    0.334s      770         56.5    482
#   8192    8193    5.219s     1570         53.3    424
#  16384   16385   10.065s     1628         55.6    549
#  32768   32769   20.576s     1593         54.7    474
#  65536   65537   42.069s     1558         54.2    545
# 131072  131073   88.384s     1483         50.0    523
# 196608  196609  134.001s     1467         52.9    417
# 260096  260097  180.827s     1438         50.3    365

# bench-gufo --nothink:
# target      pp      ttft   avg pp   decode tps    gen
#    256     259    0.340s      761         45.0    397
#   8192    8195    5.318s     1541         44.4    546
#  16384   16387    9.890s     1657         42.4    757
#  32768   32771   20.220s     1621         42.8    707
#  65536   65539   42.383s     1546         47.7   1024
# 131072  131075   86.944s     1508         46.0    613
# 196608  196611  133.502s     1473         47.5    736
# 260096  260099  180.798s     1439         43.8    994

# bench-gufo --think --concurrency 2 (last row per size only):
# target      pp      ttft   avg pp   decode tps    gen
#    256     257    0.510s      547         38.2    607
#   8192    8193   12.638s      648         31.8    474
#  16384   16385   21.883s      751         32.0    566
#  32768   32769   43.844s      748         33.1    497
#  65536   65537   89.841s      729         32.2    398
# 131072  131073  183.417s      715         32.6    399

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
    model =
      "${pkgs.qwen38-flash-next-ud-q4kxl}/" +
      "Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf";
    mtpModel = pkgs.qwen38-flash-next-mtp-q80;
    servedModelName = "qwen3.8-flash-next";
    context = 262144;
    speculative = "mtp";
    sessions = 2;

    extraArgs = [
      "--mmproj" "${pkgs.qwen38-flash-next-mmproj-bf16}"
      # quite a perf hit:
      # https://github.com/gufo-org/gufo/pull/561#issuecomment-6287816119
      "--kv-quant" "q8"  # fp8 has even slower prefill
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
        "GUFO_KV_WMMA=1"
        # GUFO_KV_I8=2 is the default
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
