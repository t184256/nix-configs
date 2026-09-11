{ pkgs, lib, config, utils, ... }:

let
  qwen35NoThinkAttrs = ''
    ctx-size = 262144
    temp = 0.7
    top-p = 0.8
    top-k = 20
    min-p = 0.0
    presence-penalty = 1.5
    chat-template-kwargs = {"enable_thinking": false}
  '';

  # greedy, raw completion (no chat template)
  completionAttrs = ''
    temp = 0
  '';

  generatedConfig = pkgs.writeText "llama-preset-generated.ini" ''
    [*]
    mmap = off
    flash-attn = on
    cache-type-k = q8_0
    cache-type-v = q8_0
    cache-type-k-draft = q8_0
    cache-type-v-draft = q8_0

    [qwen3.8-flash-next]
    model = ${pkgs.qwen38-flash-next-ud-iq4xs}/Qwen3.8-Flash-Next-UD-IQ4_XS-00001-of-00003.gguf
    spec-draft-model = ${pkgs.qwen38-flash-next-mtp-q80}
    spec-type = draft-mtp,ngram-mod
    spec-draft-n-max = 4
    spec-draft-p-min = 0.75
    ctx-size = 262144
    parallel = 1
    load-mode = none
    # to optimize
    batch-size = 8192
    ubatch-size = 512
    threads = 4
    # todo: enable vision
    [qwen3.8-27b]
    # Q8_0: near-lossless; fits with room to spare (weights ~29 GB +
    # 4 full-ctx q8_0 KV slots ~34 GiB << 128 GiB unified)
    model = ${pkgs.qwen38-27b-q80}
    # vision, same as plum
    mmproj = ${pkgs.qwen38-27b-mmproj-f16}
    image-max-tokens = 16384
    #spec-type = draft-mtp
    #spec-draft-n-max = 2
    ${qwen35NoThinkAttrs}
    # #27572, #27148
    parallel = 1
    kv-unified = 1
    cache-ram = 65536
    [zeta-2.1]
    model = ${pkgs.zeta_2_1}
    ctx-size = 32768
    ${completionAttrs}
    [sweep-v2-7b]
    model = ${pkgs.sweep-v2-7b}
    ctx-size = 32768
    ${completionAttrs}
    [sweep-1.5b]
    model = ${pkgs.sweep-1_5b}
    ctx-size = 8192
    ${completionAttrs}
    [sweep-0.5b]
    model = ${pkgs.sweep-0_5b}
    ctx-size = 8192
    ${completionAttrs}
  '';

  effectiveConfig = "/var/lib/llama/.effective.config.ini";
  localConfig = "/var/lib/llama/config.ini";

  mergeScript = pkgs.writeShellScript "llama-merge-config" ''
    cat ${generatedConfig} > ${effectiveConfig}
    [[ ! -f ${localConfig} ]] || cat ${localConfig} >> ${effectiveConfig}
  '';

  extraFlags = [
    "--models-dir" "/var/lib/llama"
    "--models-preset" effectiveConfig
    "--models-max" "1"
    "-ngl" "999"
    "--no-mmap"
    "--jinja"
    "--offline"
  ];
in
{
  nixpkgs.overlays = [
    (import ../../overlays/llama-cpp/default.nix)
  ];
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp-engramhalo-gfx1151;
    openFirewall = true;
    settings = {
      host = "192.168.99.52";
      port = 11111;
    };
  };
  users.groups.llama-cpp = { };
  users.users.llama-cpp = {
    isSystemUser = true;
    group = "llama-cpp";
    extraGroups = [ "video" "render" ];
  };

  systemd.services.llama-cpp.serviceConfig = {
    ExecStartPre = [
      mergeScript
      "+/bin/sh -c 'sync && echo 3 > /proc/sys/vm/drop_caches'"
    ];
    ReadWritePaths = [ "/var/lib/llama" ];
    DynamicUser = lib.mkForce false;
    User = "llama-cpp";
    Group = "llama-cpp";
    # persist shader cache
    Environment = [
      "XDG_CACHE_HOME=/var/lib/llama/.cache"
      "HSA_OVERRIDE_GFX_VERSION=11.5.1"
      "ROCBLAS_USE_HIPBLASLT=1"
      # sparse-attention gather for Qwen3.8-Flash-Next; keep 0 if any preset
      # runs with parallel > 1
      "LLAMA_QSA_GATHER=1"
    ];
    # omit `-m <model>`
    ExecStart =
      let cfg = config.services.llama-cpp; in lib.mkForce [
          ""
          ("${cfg.package}/bin/llama-server --log-disable " +
          "--host ${cfg.settings.host} " +
          "--port ${builtins.toString cfg.settings.port} " +
           "${utils.escapeSystemdExecArgs extraFlags}")
        ];
  };

  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/var/lib/llama";
      user = "llama-cpp";
      group = "llama-cpp";
    }
  ];
}
