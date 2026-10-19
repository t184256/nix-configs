{ inputs, pkgs, ... }:

# Qwen3.8-Flash-Next (UD-Q4_K_XL + shared-Q8 MTP), gfx1151-only:

# bench-gufo --think:
# target      pp      ttft   pp tps   decode tps    gen
#    256     257    0.470s      547         43.4    505
#   8192    8193    5.971s     1372         45.5    519
#  16384   16385   11.138s     1471         46.6    442
#  32768   32769   21.458s     1527         43.4    551
#  65536   65537   41.893s     1564         47.1    541
# 131072  131073   84.945s     1543         45.9    382
# 196608  196609  130.213s     1510         46.2    421
# 261088  261089  177.080s     1474         44.6    351

# bench-gufo --nothink:
# target      pp      ttft   pp tps   decode tps    gen
#    256     259    0.624s      416         42.7    298
#   8192    8195    6.257s     1310         38.0    302
#  16384   16387   10.879s     1506         37.5    716
#  32768   32771   21.350s     1535         37.8    553
#  65536   65539   41.861s     1566         35.9    426
# 131072  131076   84.996s     1542         38.8    206
# 196608  196611  130.473s     1507         37.3    183
# 261088  261091  176.716s     1477         37.9    929

let
  gufo = inputs.gufo.packages.x86_64-linux.default.overrideAttrs (final: prev: {
    patches = (prev.patches or []) ++ [
      #./gufo-pr608.patch  # --kv-quant q8 + more q8 stuff
    ];
    # make unset ("auto") effort neutral, so I can leave it on auto
    postPatch = ''
      ${prev.postPatch or ""}
      substituteInPlace src/models/qwen/chat_template.cpp \
      --replace-fail 'reasoning.effort.value_or(ReasoningEffort::kXHigh)' \
                     'reasoning.effort.value_or(ReasoningEffort::kMedium)'
    '';
  });
  gufoServe = inputs.gufo.lib.mkGufoServe {
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

    extraArgs = [
      "--mmproj" "${pkgs.qwen38-flash-next-mmproj-bf16}"
      # https://github.com/gufo-org/gufo/pull/561#issuecomment-6128381655
      #"--kv-quant" "q8"
    ];

    # no explicit sampling options: gufo auto-selects for thinking on and off

    # persists every 2k! writes scale as N^2 with context! 300 GB per convo!
    # basically needs sparser spacing a HDD, and a size cap to become viable
    #cacheDisk = "/var/lib/gufo";
    #cacheDiskStagingBytes = 4 * 1024 * 1024 * 1024;  # cap at ~128k context
    #cacheDiskBytes = 17 * 1024 * 1024 * 1024;  # ~4 snapshots
    # TODO: wait for a saner cache implementation, offload to an HDD box
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
        --pp 256 8192 16384 32768 65536 131072 196608 262144 \
        --tg 1024 --runs 5 --no-cache \
        "$@"
    '')
  ];

  #environment.persistence."/mnt/persist".directories = [
  #  { directory = "/var/lib/gufo"; user = "gufo"; group = "gufo"; }
  #];
}
