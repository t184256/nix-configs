{ pkgs, lib, config, utils, ... }:

{
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp-vulkan;
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
      "--models-preset" "/var/lib/llama/config.ini"
      "--models-max" "3"
      #"--models-max" "1"
      "-ngl" "999"
      "--no-mmap"
      "--jinja"
      "--offline"
    ];
  };
  systemd.services.llama-cpp.serviceConfig = {
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
    { directory = "/var/lib/llama"; }
  ];
}
