final: prev:

let
  cpuArch = "znver4";  # Ryzen 7600 / Zen 4
  gpuArch = "86";  # RTX 3090 / Ampere SM 8.6
  rev = "3a945af45d45936341a45bbf7deda56776a4af26";
  hash = "sha256-jyQGJj33bc+OeUARWgu718kbjJ8/xDwsHTyek9ITjAA=";

  src = prev.fetchFromGitHub {
    owner = "ikawrakow";
    repo = "ik_llama.cpp";
    inherit hash rev;
  };

  inherit (prev.lib) cmakeBool cmakeFeature;
  cudaPackages = prev.cudaPackages;
in

{
  ik-llama-cpp = cudaPackages.backendStdenv.mkDerivation {
    pname = "ik-llama-cpp";
    version = "0-unstable";
    inherit src;

    patches = [
      ./ik-llama-cpp-n-depth.patch
    ];

    nativeBuildInputs = [
      prev.cmake
      prev.ninja
      prev.pkg-config
      cudaPackages.cuda_nvcc
      prev.autoAddDriverRunpath
    ];

    buildInputs = with cudaPackages; [
      cuda_cccl
      cuda_cudart
      libcublas
      prev.openssl
    ];

    cmakeFlags = [
      (cmakeFeature "BUILD_COMMIT" (builtins.substring 0 7 rev))
      (cmakeBool "GGML_CUDA" true)
      (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" gpuArch)
      (cmakeBool "LLAMA_BUILD_TESTS" false)
      (cmakeBool "LLAMA_BUILD_EXAMPLES" true)
      #(cmakeBool "LLAMA_BUILD_SERVER" true)
      (cmakeBool "GGML_NATIVE" false)
      (cmakeBool "GGML_NCCL" false)  # single GPU for now
      (cmakeFeature "CMAKE_C_FLAGS" "-march=${cpuArch}")
      (cmakeFeature "CMAKE_CXX_FLAGS" "-march=${cpuArch}")
    ];
  };
}
