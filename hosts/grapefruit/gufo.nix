{ inputs, pkgs, ... }:

# Qwen3.8-Flash-Next (UD-Q4_K_XL + shared-Q8 MTP), gfx1151-only:
# compared to gufo, it gains q8 and impressive parallelism, sacrificing prefill:
# https://github.com/gufo-org/gufo/pull/561#issuecomment-6281046627

# bench-gufo --think:
# target      pp      ttft   avg pp   decode tps    gen
#    256     257    0.349s      736         48.1    596
#   8192    8193    7.916s     1035         53.3    537
#  16384   16385   15.506s     1057         49.8    385
#  32768   32769   31.260s     1048         49.8    506
#  65536   65537   65.816s      996         51.9    535
# 131072  131073  135.635s      966         51.4    539
# 196608  196609  208.438s      943         50.8    308
# 260096  260097  282.605s      920         51.2    386

# bench-gufo --nothink:
# target      pp      ttft   avg pp   decode tps    gen
#    256     259    0.357s      725         45.7    392
#   8192    8196    7.833s     1046         42.8    605
#  16384   16387   15.628s     1049         45.7    584
#  32768   32771   32.119s     1020         42.1    324
#  65536   65539   65.298s     1004         43.1   1017
# 131072  131075  135.516s      967         43.1    195
# 196608  196611  208.264s      944         46.9    538
# 260096  260099  282.489s      921         46.4   1024

# bench-gufo --think --concurrency 2 (last row per size only):
#    256     257    0.709s      362         33.6    554
#   8192    8193   16.428s      502         33.3    432
#  16384   16385   32.221s      512         28.7    468
#  32768   32769   67.929s      482         29.3    468
#  65536   65537  136.815s      479         29.3    501
# 131072  131073  276.000s      475         29.0    443
# 196608  196609  427.749s      460         27.1    376
# 260096  260097  589.190s      441         26.3    360

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
        --no-exact-tg \
        "$@"
    '')
  ];

  #environment.persistence."/mnt/persist".directories = [
  #  { directory = "/var/lib/gufo"; user = "gufo"; group = "gufo"; }
  #];
}
