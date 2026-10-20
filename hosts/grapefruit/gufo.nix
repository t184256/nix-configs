{ inputs, pkgs, ... }:

# Qwen3.8-Flash-Next (UD-Q4_K_XL + shared-Q8 MTP), gfx1151-only:
# compared to gufo, it gains q8 and impressive parallelism, sacrificing prefill:
# https://github.com/gufo-org/gufo/pull/561#issuecomment-6281046627

# TODO: update

# bench-gufo --think:
# target      pp      ttft   pp tps   decode tps    gen
#    256     257    0.371s      693         41.5    553
#   8192    8193    8.100s     1012         42.2    571
#  16384   16385   15.473s     1059         40.9    472
#  32768   32769   30.506s     1074         43.0    536
#  65536   65537   61.180s     1071         44.7    491
# 131072  131073  195.513s      670         32.4    511
# 196608  196609  199.027s      988         42.3    323
# 260096  260097  348.298s      747         39.1    526
# bench-gufo --nothink:
# target      pp      ttft   pp tps   decode tps    gen
#    256     259    0.371s      699         39.1    453
#   8192    8195    7.836s     1046         36.7    877
#  16384   16387   15.346s     1068         37.5    835
#  32768   32771   31.120s     1053         38.8    424
#  65536   65539   62.455s     1049         36.0    865
# 131072  131075  128.729s     1018         36.9   1024
# 196608  196611  200.275s      982         38.4   1024
# 260096  260099  266.509s      976         38.3   1024

# bench-gufo --think --concurrency 2 (last row per size only):
#    256     257    0.738s      348         30.2    571
#   8192    8193   17.482s      469         28.3    527
#  16384   16385   34.285s      478         27.0    569
#  32768   32769   66.888s      490         27.3    509
#  65536   65537  130.643s      502         27.4    570
# 131072  131073  262.302s      500         25.9    474
# 196608  196609  410.207s      479         26.2    448

let
  gufo = inputs.mbufo.packages.x86_64-linux.default.overrideAttrs (_: prev: {
    # make unset ("auto") effort neutral, so I can leave it on auto
    postPatch = ''
      ${prev.postPatch or ""}
      substituteInPlace src/models/qwen/chat_template.cpp \
      --replace-fail 'reasoning.effort.value_or(ReasoningEffort::kXHigh)' \
                     'reasoning.effort.value_or(ReasoningEffort::kMedium)'
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
        "$@"
    '')
  ];

  #environment.persistence."/mnt/persist".directories = [
  #  { directory = "/var/lib/gufo"; user = "gufo"; group = "gufo"; }
  #];
}
