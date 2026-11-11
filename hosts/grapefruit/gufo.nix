{ inputs, pkgs, ... }:

# Qwen3.8-Flash-Next (UD-Q4_K_XL + shared-Q8 MTP), gfx1151-only:
# compared to gufo, it gains q8 and impressive parallelism, sacrificing prefill:
# https://github.com/gufo-org/gufo/pull/561#issuecomment-6281046627

# bench-gufo --think:
# target      pp      ttft   avg pp   decode tps    gen
#    256     257    0.359s      715         50.5    548
#   8192    8193    6.086s     1346         50.6    556
#  16384   16385   11.781s     1391         50.6    430
#  32768   32769   23.946s     1368         49.1    476
#  65536   65537   50.514s     1297         54.4    391
# 131072  131073  104.611s     1253         54.5    401
# 196608  196609  161.466s     1218         50.9    434
# 260096  260097  218.604s     1190         50.2    388

# bench-gufo --nothink:
# target      pp      ttft   avg pp   decode tps    gen
#    256     259    0.353s      734         47.4    446
#   8192    8196    6.063s     1352         42.3    799
#  16384   16387   11.709s     1400         45.8    637
#  32768   32771   24.489s     1338         41.5    842
#  65536   65539   50.180s     1306         42.4    943
# 131072  131075  104.594s     1253         40.9    778
# 196608  196611  160.771s     1223         43.2    820
# 260096  260099  217.942s     1193         41.5    951

# bench-gufo --think --concurrency 2 (last row per size only):
# target      pp      ttft   avg pp   decode tps    gen
#    256     257    0.706s      364         34.8    487
#   8192    8193   14.265s      574         30.9    539
#  16384   16385   26.034s      631         30.2    465
#  32768   32769   53.526s      612         30.1    454
#  65536   65537  104.739s      626         30.6    493
# 131072  131073  214.983s      610         27.5    431
# 196608  196609  338.688s      581         25.4    357
# 260096  260097  463.141s      562         23.8    394

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
      # recover pp throughput, risk correctness
      Environment = [ "GUFO_KV_WMMA=1" "GUFO_KV_I8=1" ];
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
