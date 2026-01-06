{pkgs, ...}:

{
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp-vulkan;
    #package = pkgs.llama-cpp-rocm;
    #package = pkgs.llama-cpp.override {
    #  rocmSupport = true;
    #  rocmGpuTargets = [ "gfx1151" ];
    #};  # faster on long contexts, but hangs on loading larger models?
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
    model = "/var/lib/llama/model.gguf";
    #model = "/var/lib/llama/draft-model.gguf";
    extraFlags = [
      #"--model-draft" "/var/lib/llama/draft-model.gguf"
      #"--ctx-size" "0"
      "--ctx-size" "262144" "--parallel" "2"
      "--ubatch-size" "2048" "--batch-size" "32768"
      "--flash-attn" "on"
      "--temp" "1.0" "--top-p" "1.0"
      #"--top-k" "0.0"  # ggml-org/llama.cpp#15223
      "--min-p" "0.01"
      "--jinja"
      #"--chat-template-kwargs" "{\"reasoning_effort\": \"high\"}"
      "--offline"
    ];
  };
  environment.persistence."/mnt/persist".directories = [
    { directory = "/var/lib/llama"; }
  ];
}
