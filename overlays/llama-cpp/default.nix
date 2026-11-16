_: prev:

let
  newerVer = "1.0.0";  # no support for b##### versions, only semver ones
  isFresh = v: prev.lib.versionAtLeast v newerVer;
  freshen = prevLlamaCpp:
    assert !prev.lib.strings.hasPrefix "b" prevLlamaCpp.version;
    if isFresh prevLlamaCpp.version
    then prevLlamaCpp
    else prevLlamaCpp.overrideAttrs overrides-fresh;
  overrides-fresh = oa:
    rec {
    name = "llama-cpp-${newerVer}";
    version = newerVer;
    src = prev.fetchFromGitHub {
      owner = "ggml-org";
      repo = "llama.cpp";
      tag = "v${newerVer}";
      hash = "sha256-aYziwYzK9Zj7sopAEsrANhMGs4BO0F2g0cDCGmYLxDA=";
      leaveDotGit = true;
      postFetch = ''
        git -C "$out" rev-parse --short HEAD > $out/COMMIT
        find "$out" -name .git -print0 | xargs -0 rm -rf
      '';
    };
    patches = prev.lib.remove
      (prev.fetchpatch { # #30034 is already in v0.7.0
        url = "https://github.com/ggml-org/llama.cpp/commit/" +
              "07ccce23cf7fe3c84e13d810accff672b1d966bf.patch";
        hash = "sha256-KtsPcveFM51fY1hDWntiqCW/KHoWLv05Gmnhd1U/9Zs=";
      })
      (oa.patches or []);
    npmDepsHash = "sha256-0OJIueUN5oD/V2NtVcXTiRW59u2tJIG3OxW8aJ8JDBY=";
    npmDeps = prev.fetchNpmDeps {
      # tying name to src to force rebuilds on src changes
      name = "llama-cpp-${newerVer}-npm-deps-${prev.lib.baseNameOf src}";
      inherit src patches;
      preBuild = ''
        pushd tools/ui
      '';
      hash = npmDepsHash;
    };
    disabledTests = (oa.disabledTests or []) ++ [
      "test-llama-context-model"  # 0.7.0 addition
      "test-conversion-fp8"  # 0.9.0 addition, needs torch/safetensors/numpy
      "test-kv-cache-scales"  # 1.0.0 addition, fails under pinned torch
    ];
  };
in
rec {
  llama-cpp = freshen prev.llama-cpp;

  llama-cpp-vulkan = llama-cpp.override { vulkanSupport = true; };
  llama-cpp-rocm = llama-cpp.override { rocmSupport = true; };
  llama-cpp-cuda-vulkan = (llama-cpp.override {
    cudaSupport = true;
    vulkanSupport = true;
  }).overrideAttrs (oa: {
    cmakeFlags = (oa.cmakeFlags or []) ++ [ "-DGGML_CUDA_NCCL=ON" ];
    buildInputs = (oa.buildInputs or []) ++ [ prev.cudaPackages.nccl ];
  });

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
