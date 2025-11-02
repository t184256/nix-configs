{pkgs, ...}:

{
  services.llama-cpp = {
    enable = true;
    #package = pkgs.llama-cpp.override { vulkanSupport = true; };
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
    host = "192.168.99.7";
    port = 11111;
    model = "/var/lib/llama/model.gguf";
    extraFlags = [
      #"-c" "16384"
      "-c" "32768"
      "-ub" "2048" "-b" "2048"
      "--jinja"
    ];
  };
  environment.persistence."/mnt/persist".directories = [
    { directory = "/var/lib/llama"; }
  ];
}
