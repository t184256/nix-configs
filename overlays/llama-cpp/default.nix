final: prev:
# Doesn't work with non-default python version

let
  newerVer = "b10786";
  # b-versions like 10408 compare higher that v-versions like 0.3.0,
  # treat them as older
  # isFresh = v:
  #   (prev.lib.strings.match "^[0-9]+$" v) == null &&
  #   prev.lib.versionAtLeast v newerVer;
  freshen = prevLlamaCpp:
    # if isFresh prevLlamaCpp.version
    # then prevLlamaCpp
    # else
    prevLlamaCpp.overrideAttrs overrides-fresh;
  overrides-fresh = _: {
    name = "llama-cpp-${newerVer}";
    version = newerVer;
    src = prev.fetchFromGitHub {
      owner = "ggml-org";
      repo = "llama.cpp";
      tag = "${newerVer}";
      hash = "sha256-y0WvekNed7gjXeXW64LYj5L0a5gWv0/d3cA8njVAYzQ=";
      leaveDotGit = true;
      postFetch = ''
        git -C "$out" rev-parse --short HEAD > $out/COMMIT
        find "$out" -name .git -print0 | xargs -0 rm -rf
      '';
    };
    npmDepsHash = "sha256-2Q7XhaLAArmviOLdQsNbYTfdyDE5pW9lR26cRHEVl9k=";
  };
  cuda-vulkan = (prev.llama-cpp.override {
    cudaSupport = true;
    vulkanSupport = true;
  }).overrideAttrs (oa: {
    cmakeFlags = (oa.cmakeFlags or []) ++ [ "-DGGML_CUDA_NCCL=ON" ];
    buildInputs = (oa.buildInputs or []) ++ [ prev.cudaPackages.nccl ];
  });
in
rec {
  llama-cpp = freshen prev.llama-cpp;
  llama-cpp-vulkan = freshen prev.llama-cpp-vulkan;
  llama-cpp-rocm = freshen prev.llama-cpp-rocm;
  llama-cpp-cuda-vulkan = freshen cuda-vulkan;

  llama-cpp-rocm-gfx1151 = (llama-cpp.override {
    rocmSupport = true;
    rocmGpuTargets = [ "gfx1151" ];
  }).overrideAttrs (_: {
    name = "llama-cpp-rocm-gfx1151-${newerVer}";
  });
  llama-cpp-rocm-gfx1102 = (llama-cpp.override {
    rocmSupport = true;
    rocmGpuTargets = [ "gfx1102" ];
  }).overrideAttrs (_: {
    name = "llama-cpp-rocm-gfx1102-${newerVer}";
  });

  llama-cpp-engramhalo-gfx1151 = (llama-cpp.override {
    rocmSupport = true;
    rocmGpuTargets = [ "gfx1151" ];
  }).overrideAttrs (oldArgs: {
    name = "llama-cpp-engramhalo-gfx1151";
    cmakeFlags = (oldArgs.cmakeFlags or []) ++ [
      "-DGGML_HIP_FORCE_MMQ=ON"
      "-DGGML_HIP_ROCWMMA_FATTN=OFF"
    ];
    src = prev.fetchFromGitHub {
      owner = "Aristo94";
      repo = "EngramHalo.cpp";  # qwen4exp, --tensor-read-lazy
      rev = "4ff3affc2ac5861f7dda42bcf5ff653c776b816f";  # newer 4e3ff47 is slow
      hash = "sha256-JDtgXX741amKxHsiB1icFgb/uUpgmilrfURAZTo5TCY=";
      leaveDotGit = true;
      postFetch = ''
        git -C "$out" rev-parse --short HEAD > $out/COMMIT
        find "$out" -name .git -print0 | xargs -0 rm -rf
      '';
    };
    npmDepsHash = "sha256-2Q7XhaLAArmviOLdQsNbYTfdyDE5pW9lR26cRHEVl9k=";
  });
}
