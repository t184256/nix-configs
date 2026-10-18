{ pkgs, lib, ... }:

# LFM2.5-8B-A2B (UD-Q4_K_XL) on gfx1151, serial (parallel = 1, ctx 128000).
# The decision model and whisper.cpp used to share this unit; both moved to
# cocoa, which has the memory headroom.

# bench-mini:
# target      pp      ttft   pp tps   decode tps    gen
#    256     256    0.106s     2408        133.5    628
#   1024    1024    0.264s     3881        132.8    661
#   4096    4096    0.899s     4559        130.4   1024
#   8192    8192    1.793s     4569        127.0   1024
#  16384   16384    3.741s     4379        122.0    686
#  32768   32768    8.367s     3916        111.9   1024
#  65536   65536   22.908s     2861         87.0   1024
#  98304   98304   61.661s     1594         21.0   1024
# 126464  (not recorded: llama-cpp.service died during this leg, and the
#          host only answers on 11111/11112 afterwards)
#
# gen < 1024 means the model reached EOS early, not a truncation.
# Beyond 65536 both pp and decode fall off a cliff (q8_0 KV + load-mode = none
# over 112 GiB GTT), so the default sweep below stops at 98304; add
# `--pp 126464` explicitly if you want to poke at it again.
# For reference, parallel = 2 gave 94.9 decode t/s per stream (190 aggregate)
# and roughly doubled ttft - prompt processing does not scale with slots.

let
  # LFM2.5-8B-A1B (lfm2moe): sampling defaults from the model card.
  # Thinking is not a server-side switch here - the template only honours
  # chat_template_kwargs.preserve_thinking per request.
  lfm25Attrs = ''
    ctx-size = 128000
    temp = 0.2
    top-k = 80
    repeat-penalty = 1.05
    # serial: one slot gets the whole trained 128000 (131072 would trip
    # "n_ctx_seq > n_ctx_train" - max_position_embeddings really is 128000)
    # TODO: parallel - revisit once the full-context serial curve is recorded
    parallel = 1
  '';

  generatedConfig = pkgs.writeText "llama-preset-generated.ini" ''
    [*]
    # new name for mmap = off:
    load-mode = none
    flash-attn = on
    cache-type-k = q8_0
    cache-type-v = q8_0
    batch-size = 8192
    ubatch-size = 2048
    threads = 4

    [LFM2.5-8B-A2B]
    # router-level alias: requests may say "mini" instead of the section name
    alias = mini
    model = ${pkgs.lfm25-8b-a1b-ud-q4kxl}
    # resident from the start: 5.1 GiB of weights is nothing here, and nobody
    # should pay a load on the first request
    load-on-startup = true
    ${lfm25Attrs}
  '';


in
{
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp-rocm-gfx1151;
    openFirewall = true;
    # settings is a freeform attrs submodule: each key turns into a
    # llama-server flag (--key value, bools bare). Leaving out `model` keeps
    # the server in router mode over the preset below.
    settings = {
      host = "192.168.99.52";
      # kept at 11113 (whisper used to hold 11112 here; it is on cocoa now) so
      # slop-forward's grapefruitMini backend did not have to move
      port = 11113;
      models-dir = "/var/lib/llama";
      # straight out of the store: tweak this file instead of dropping a
      # runtime override next to it
      models-preset = generatedConfig;
      # chat only now: the decision model (d1-3B) and whisper live on cocoa,
      # see hosts/cocoa/llama-cpp-decision.nix
      models-max = 1;
      n-gpu-layers = 999;
      jinja = true;
      offline = true;
      # no log-disable: preset loading is worth seeing in journalctl
    };
  };
  users.groups.llama-cpp = { };
  users.users.llama-cpp = {
    isSystemUser = true;
    group = "llama-cpp";
    extraGroups = [ "video" "render" ];
  };

  systemd.services.llama-cpp.serviceConfig = {
    ReadWritePaths = [ "/var/lib/llama" ];
    DynamicUser = lib.mkForce false;
    User = "llama-cpp";
    Group = "llama-cpp";
    MemorySwapMax = 0;  # let's just not
    # persist shader cache
    Environment = [
      "XDG_CACHE_HOME=/var/lib/llama/.cache"
      "HSA_OVERRIDE_GFX_VERSION=11.5.1"
      "ROCBLAS_USE_HIPBLASLT=1"
    ];
  };

  # bench-mini [llama-benchy args...]
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "bench-mini" ''
      exec ${pkgs.llama-benchy-nice}/bin/llama-benchy-nice \
        --base-url http://192.168.99.52:11113/v1 \
        --model mini \
        --tokenizer lfm2.5 \
        --pp 256 1024 4096 8192 16384 32768 65536 98304 \
        --tg 1024 --runs 3 --no-cache --concurrency 1 \
        "$@"
    '')
  ];

  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/var/lib/llama";
      user = "llama-cpp";
      group = "llama-cpp";
    }
  ];
}
