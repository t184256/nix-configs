{ inputs, pkgs, ... }:

# Qwen3.8-Flash-Next (UD-Q4_K_XL + shared-Q8 MTP), gfx1151-only:
# compared to gufo, it gains q8 and impressive parallelism, sacrificing prefill:
# https://github.com/gufo-org/gufo/pull/561#issuecomment-6281046627

# bench-gufo --think:
# target      pp      ttft   avg pp   decode tps    gen
# target      pp      ttft   avg pp   decode tps    gen
#    256     257    0.367s      701         50.8    606
#   8192    8193    8.041s     1019         49.7    614
#  16384   16385   15.579s     1052         49.9    505
#  32768   32769   31.441s     1042         50.0    437
#  65536   65537   66.302s      988         48.7    527
# 131072  131073  136.681s      959         52.6    409
# 196608  196609  209.663s      938         49.9    459
# 260096  260097  284.412s      915         48.5    357
# target      pp      ttft   avg pp   decode tps    gen

# bench-gufo --nothink:
# target      pp      ttft   avg pp   decode tps    gen
#    256     259    0.362s      717         45.3    251
#   8192    8195    7.859s     1043         39.9    626
#  16384   16387   15.635s     1048         41.0    679
#  32768   32772   32.307s     1014         45.2    971
#  65536   65539   65.706s      997         45.9   1024
# 131072  131075  135.863s      965         41.2    895
# 196608  196611  209.186s      940         43.6   1024
# 260096  260099  283.942s      916         42.1   1024

# bench-gufo --think --concurrency 2 (last row per size only):
# target      pp      ttft   avg pp   decode tps    gen
#    256     257    0.728s      353         35.3    620
#   8192    8193   17.237s      476         30.4    586
#  16384   16385   31.504s      524         28.4    594
#  32768   32769   68.846s      476         24.8    451
#  65536   65537  137.545s      476         31.3    513
# 131072  131073  279.339s      469         30.2    492
# 196608  196609  428.717s      459         30.1    370
# 260096  260097  589.714s      441         26.0    338

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
      #Environment = [ "GUFO_KV_WMMA=1" ];  # recover pp throughput, go paranoid
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
