{ inputs, pkgs, ... }:

# Qwen3.8-Flash-Next (UD-Q4_K_XL + shared-Q8 MTP), gfx1151-only:
# compared to gufo, it gains q8 and impressive parallelism, sacrificing prefill:
# https://github.com/gufo-org/gufo/pull/561#issuecomment-6281046627

# 95530M GTT / 109G of actual usage

# bench-gufo --think:
# target      pp      ttft   avg pp   decode tps    gen
#    256     257    0.344s      748         51.8    562
#   8192    8193    5.845s     1402         53.2    400
#  16384   16385   11.244s     1457         54.0    486
#  32768   32769   23.305s     1406         52.8    500
#  65536   65537   48.130s     1362         52.7    477
# 131072  131074   99.657s     1315         53.5    433
# 196608  196609  153.627s     1280         52.1    496
# 260096  260097  208.684s     1246         50.3    373

# bench-gufo --nothink:
# target      pp      ttft   avg pp   decode tps    gen
#    256     259    0.351s      737         48.7    337
#   8192    8195    5.784s     1417         46.5    678
#  16384   16387   11.225s     1460         45.6   1010
#  32768   32771   22.875s     1433         48.2    823
#  65536   65539   47.574s     1378         46.7    790
# 131072  131075   99.676s     1315         44.8   1024
# 196608  196611  152.729s     1287         43.4   1024
# 260096  260099  207.563s     1253         43.1    219

# bench-gufo --think --concurrency 2 (last row per size only):
# target      pp      ttft   avg pp   decode tps    gen
#    256     257    0.678s      377         35.3    773
#   8192    8193   11.218s      730         33.7    570
#  16384   16385   21.289s      770         34.7    468
#  32768   32769   50.469s      649         35.4    454
#  65536   65537  108.431s      604         33.5    535
# 131072  131073  204.031s      642         34.9    441
# 196608  196609  316.806s      621         32.0    374
# 260096  260097  444.659s      585         27.4    329

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
