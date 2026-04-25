{ pkgs, lib, config, utils, ... }:

let
  qwen35NoThinkAttrs = ''
    ctx-size = 196608
    temp = 0.7
    top-p = 0.8
    top-k = 20
    min-p = 0.0
    presence-penalty = 1.5
    chat-template-kwargs = {"enable_thinking": false}
  '';

  # greedy, raw completion (no chat template)
  sweepAttrs = ''
    temp = 0
  '';

  generatedConfig = pkgs.writeText "llama-preset-generated.ini" ''
    [*]
    mmap = off
    flash-attn = on

    [qwen3.5-0.8b]
    model = ${pkgs.qwen35-08b-q4kxl}
    ${qwen35NoThinkAttrs}
    [qwen3.6-27b]
    model = ${pkgs.qwen36-27b-q4kxl}
    ${qwen35NoThinkAttrs}
    [qwen3.5-35b-a3b]
    model = ${pkgs.qwen35-35b-a3b-mxfp4}
    ${qwen35NoThinkAttrs}
    [qwen3.6-35b-a3b]
    model = ${pkgs.qwen36-35b-a3b-mxfp4}
    ${qwen35NoThinkAttrs}
    [qwen3.5-122b-a10b]
    model = ${pkgs.qwen35-122b-a10b-mxfp4}/Qwen3.5-122B-A10B-MXFP4_MOE-00001-of-00003.gguf
    ${qwen35NoThinkAttrs}
    [qwen3.6-27b-drafted]
    # 11.63 -> 12.45 =) in geese test
    model = ${pkgs.qwen36-27b-q4kxl}
    model-draft = ${pkgs.qwen35-08b-q4kxl}
    ${qwen35NoThinkAttrs}
    [qwen3.6-27b-drafted2]
    # 11.63 -> 12.05
    model = ${pkgs.qwen36-27b-q4kxl}
    model-draft = ${pkgs.qwen35-2b-q4kxl}
    ${qwen35NoThinkAttrs}
    [qwen3.6-27b-drafted4]
    # 11.63 -> 11.29 =(
    model = ${pkgs.qwen36-27b-q4kxl}
    model-draft = ${pkgs.qwen35-4b-q4kxl}
    ${qwen35NoThinkAttrs}
    [qwen3.5-35b-a3b-drafted]
    # 50.77 -> 38.62 =(
    model = ${pkgs.qwen35-35b-a3b-mxfp4}
    model-draft = ${pkgs.qwen35-08b-q4kxl}
    ${qwen35NoThinkAttrs}
    [qwen3.5-122b-a10b-drafted]
    # 20.79 -> 17.06 =(
    model = ${pkgs.qwen35-122b-a10b-mxfp4}/Qwen3.5-122B-A10B-MXFP4_MOE-00001-of-00003.gguf
    model-draft = ${pkgs.qwen35-08b-q4kxl}
    ${qwen35NoThinkAttrs}
    [qwen3.6-35b-a3b-drafted]
    # 51.28 -> 34.29 =(
    model = ${pkgs.qwen36-35b-a3b-mxfp4}
    model-draft = ${pkgs.qwen35-08b-q4kxl}
    ${qwen35NoThinkAttrs}
    [sweep-v2-7b]
    model = ${pkgs.sweep-v2-7b}
    ctx-size = 32768
    ${sweepAttrs}
    [sweep-1.5b]
    model = ${pkgs.sweep-1_5b}
    ctx-size = 8192
    ${sweepAttrs}
    [sweep-0.5b]
    model = ${pkgs.sweep-0_5b}
    ctx-size = 8192
    ${sweepAttrs}
  '';

  effectiveConfig = "/var/lib/llama/.effective.config.ini";
  localConfig = "/var/lib/llama/config.ini";

  mergeScript = pkgs.writeShellScript "llama-merge-config" ''
    cat ${generatedConfig} > ${effectiveConfig}
    [[ -f ${localConfig} ]] && cat ${localConfig} >> ${effectiveConfig}
  '';
in
{
  services.llama-cpp = {
    enable = true;
    #package = pkgs.llama-cpp-vulkan;
    package = pkgs.llama-cpp-rocm-gfx1151;
    #package = pkgs.llama-cpp.override {
    #  rocmSupport = true;
    #  rocmGpuTargets = [ "gfx1151" ];
    #};  # what's better really depends on the model / ctx
    #package = (pkgs.llama-cpp.override {
    #  rocmSupport = true;
    #  rocmGpuTargets = [ "gfx1151" ];
    #}).overrideAttrs(_: {
    #  src = pkgs.fetchFromGitHub {
    #    owner = "lhl";
    #    repo = "llama.cpp";
    #    rev = "a45e1cd6e9f306a4708cb98912b2bd37e8b70fff";
    #    hash = "sha256-LiXdXNfakeNHM5HAIVtE7uR+T6zRmbBw26sjrRJ8mdg=";
    #    leaveDotGit = true;
    #    postFetch = ''
    #      git -C "$out" rev-parse --short HEAD > $out/COMMIT
    #      find "$out" -name .git -print0 | xargs -0 rm -rf
    #    '';
    #  };
    #});
    #package = pkgs.llama-cpp.overrideAttrs(oa: {
    #  cmakeFlags = oa.cmakeFlags ++ [
    #    "-DGGML_SYCL=ON"
    #    "-DGGML_SYCL_F16:BOOL=ON"
    #  ];
    #  buildInputs = oa.buildInputs ++ (with pkgs; [
    #    intel-compute-runtime mkl oneDNN_2
    #  ]);
    #});
    openFirewall = true;
    host = "192.168.99.52";
    port = 11111;
    model = "/-unused-";
    extraFlags = [
      "--models-dir" "/var/lib/llama"
      "--models-preset" effectiveConfig
      "--models-max" "2"
      #"--models-max" "1"
      "--parallel" "1"
      "-ngl" "999"
      "--no-mmap"
      "--jinja"
      "--offline"
    ];
  };
  users.groups.llama-cpp = { };
  users.users.llama-cpp = {
    isSystemUser = true;
    group = "llama-cpp";
    extraGroups = [ "video" "render" ];
  };

  systemd.services.llama-cpp.serviceConfig = {
    ExecStartPre = [ mergeScript ];
    ReadWritePaths = [ "/var/lib/llama" ];
    DynamicUser = lib.mkForce false;
    User = "llama-cpp";
    Group = "llama-cpp";
    # persist shader cache
    Environment = [ "XDG_CACHE_HOME=/var/lib/llama/.cache" ];
    # omit `-m <model>`
    ExecStart =
      let cfg = config.services.llama-cpp; in lib.mkForce [
          ""
          ("${cfg.package}/bin/llama-server --log-disable " +
           "--host ${cfg.host} --port ${builtins.toString cfg.port} " +
           "${utils.escapeSystemdExecArgs cfg.extraFlags}")
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
