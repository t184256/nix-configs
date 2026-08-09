final: prev:
# Doesn't work with non-default python version

let
  newerVer = "10313";
  overrides-fresh = old: {
    name = "llama-cpp-${newerVer}";
    version = newerVer;
    src = prev.fetchFromGitHub {
      owner = "ggml-org";
      repo = "llama.cpp";
      tag = "b${newerVer}";
      hash = "sha256-tHqT6Fh4ZM8vBrA+hQjh+3kbq+6FL60rcdWCH1NT8eg=";
      leaveDotGit = true;
      postFetch = ''
        git -C "$out" rev-parse --short HEAD > $out/COMMIT
        find "$out" -name .git -print0 | xargs -0 rm -rf
      '';
    };
    npmDepsHash = "sha256-FHvd2bMvBc9EXrJEzu8EN78oUVSLcOKYCc0232V+L4A=";
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
  llama-cpp =
    if prev.lib.versionAtLeast prev.llama-cpp.version newerVer
    then prev.llama-cpp
    else prev.llama-cpp.overrideAttrs overrides-fresh;
  llama-cpp-vulkan =
    if prev.lib.versionAtLeast prev.llama-cpp-vulkan.version newerVer
    then prev.llama-cpp-vulkan
    else prev.llama-cpp-vulkan.overrideAttrs overrides-fresh;
  llama-cpp-rocm =
    if prev.lib.versionAtLeast prev.llama-cpp-rocm.version newerVer
    then prev.llama-cpp-rocm
    else prev.llama-cpp-rocm.overrideAttrs overrides-fresh;

  llama-cpp-cuda-vulkan =
    if prev.lib.versionAtLeast prev.llama-cpp-rocm.version newerVer
    then cuda-vulkan
    else cuda-vulkan.overrideAttrs overrides-fresh;

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
}
