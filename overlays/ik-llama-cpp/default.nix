final: prev:

let
  cpuArch = "znver4";  # Ryzen 7600 / Zen 4
  gpuArch = "86";  # RTX 3090 / Ampere SM 8.6
  rev = "fac404509cf3a015305e1e256ca284de036109d3";
  hash = "sha256-FEibfX8j3rfeIgdMCUMXc43kdT5j30GZ8Qk7Ionxdv8=";

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
      ./20970.patch
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
