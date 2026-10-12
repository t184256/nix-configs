{ inputs, pkgs, ... }:

# Qwen3.8-Flash-Next (UD-Q4_K_XL + shared-Q8 MTP), gfx1151-only:
# ~1500-1600 pp, ~32-37 tg to 256k context
let
  gufo = inputs.gufo.packages.x86_64-linux.default.overrideAttrs (final: prev: {
    # --kv-quant q8
    # https://github.com/gufo-org/gufo/pull/561.patch as of 2026-10-12
    patches = (prev.patches or []) ++ [ (pkgs.fetchpatch {
      url =
        "https://github.com/dardeaw/gufo/commit/" +
        "e644a92f2487cb85a78d64c60b3709dbea0caa91.patch";
      hash = "sha256-bevyN4C4Hys49CvkeS2KyhdY0rEK9LQl6NTE3sJitQY=";
    }) ];
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
      "--mmproj" (toString pkgs.qwen38-flash-next-mmproj-bf16)
      #"--kv-quant" "q8"  # untested
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
      ExecStart = [ gufoServe ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 11111 ];

  #environment.persistence."/mnt/persist".directories = [
  #  { directory = "/var/lib/gufo"; user = "gufo"; group = "gufo"; }
  #];
}
