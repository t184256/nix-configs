final: prev:

# override nixpkgs vllm with custom patches and SM86-only build
#
# external cmake deps (CUDA only):
#   cutlass v4.2.1       - nixpkgs (via oa.cmakeFlags FETCHCONTENT_SOURCE_DIR)
#   FlashMLA              - nixpkgs (via oa.cmakeFlags FLASH_MLA_SRC_DIR)
#   qutlass               - nixpkgs (via oa.cmakeFlags QUTLASS_SRC_DIR)
#   vllm-flash-attn       - overridden below (exact nightly pin)
#   triton-kernels 3.6.0  - overridden below via env (nixpkgs has 3.5.0)
#   deepgemm              - added below via cmakeFlags (SM90+/SM100 only)

let
  xgrammar = prev.python313Packages.xgrammar.overrideAttrs (oa: {
    version = "0.2.3";
    src = prev.fetchFromGitHub {
      owner = "mlc-ai";
      repo = "xgrammar";
      rev = "557becfb64c503ae9c04344b0047661f43f44320";
      fetchSubmodules = true;
      hash = "sha256-bznSz1fOCCGFR3NsuXm5eWo7EXrvBrFavEllC5+vDHM=";
    };
    patches = [];
    disabledTestPaths = [];
    nativeBuildInputs = oa.nativeBuildInputs
      ++ [ prev.python313Packages.apache-tvm-ffi ];
    propagatedBuildInputs = oa.propagatedBuildInputs
      ++ [ prev.python313Packages.apache-tvm-ffi ];
  });

  flashinfer = prev.python313Packages.flashinfer.overrideAttrs (oa: {
    version = "0.6.8.post1";
    src = prev.fetchFromGitHub {
      owner = "flashinfer-ai";
      repo = "flashinfer";
      tag = "v0.6.8.post1";
      fetchSubmodules = true;
      hash = "sha256-OAPR7vSxI6KZdPzvgRvl6owo6Hmi5244Y/fJ3IK5Vos=";
    };
    # Compile AOT for SM86 only; avoids JIT at runtime.
    env = (oa.env or {}) // { FLASHINFER_CUDA_ARCH_LIST = "8.6"; };
    # apache-tvm-ffi is a runtime dep (imported in flashinfer.jit) but
    # nixpkgs only puts it in build-system; add it to propagated as well.
    propagatedBuildInputs = (oa.propagatedBuildInputs or [])
      ++ [ prev.python313Packages.apache-tvm-ffi ];
    # cuda-tile is listed in requirements.txt but never imported; requires
    # CUDA 13.1+ which we don't have. Strip it like nixpkgs strips cutlass-dsl.
    pythonRemoveDeps = (oa.pythonRemoveDeps or []) ++ [ "cuda-tile" ];
    dontCheckPythonMetadata = true;
    meta = (oa.meta or {}) // { broken = false; };
  });

  overriddenVllm = (prev.python313Packages.vllm.override {
    inherit flashinfer xgrammar;
  }).overrideAttrs (oa: {
    patches =
      (prev.lib.filter
        (p: !prev.lib.hasSuffix "0006-drop-rocm-extra-reqs.patch" (toString p))
        oa.patches)
      ++ [
           # quack-kernels/cutlass-dsl not packaged in nixpkgs
           ./0007-drop-quack-reqs.patch
           # VLLM_CUDA_ARCHS_OVERRIDE hook; SM86-only, binary-cache-safe
           ./0008-cuda-arch-override.patch
           # wire nix-provided cutlass into flash-attn CMake targets
           ./0009-flash-attn-cutlass-include.patch
           # SM86 GDN layers emit float32; cast before combine_hidden_states
           ./0013-dflash-cast-hidden-states-dtype.patch
           # PR #40371: prompt_progress SSE events during prefill
           ./0016-prompt-progress-api.patch
           # vllm:prefill_tokens_computed in-progress counter
           ./0019-prefill-tps-metric.patch
           # PR #39456: vllm:num_requests_prefilling/decoding gauges
           ./0020-prefill-decoding-req-gauges.patch
           # presence_penalty/frequency_penalty in generation_config defaults
           ./0021-generation-config-presence-penalty.patch
         ];
    # triton-kernels: bump to v3.6.0; nixpkgs ships 3.5.0.
    env =
      let
        triton-kernels = prev.fetchFromGitHub {
          owner = "triton-lang";
          repo = "triton";
          tag = "v3.6.0";
          hash = "sha256-JFSpQn+WsNnh7CAPlcpOcUp0nyKXNbJEANdXqmkt4Tc=";
        };
      in
      (oa.env or { }) // {
        TRITON_KERNELS_SRC_DIR =
          "${triton-kernels}/python/triton_kernels/triton_kernels";
      };
    # TORCH_CUDA_ARCH_LIST must be set in preBuild, not env:
    # CUDA setup hooks from cudaPackages run after env is initialised and
    # override both. preBuild runs after all hooks, before cmake.
    preBuild = ''
      export VLLM_CUDA_ARCHS_OVERRIDE="8.6"
      export MAX_JOBS=8
    '' + (oa.preBuild or "");
    cmakeFlags =
      let
        deepgemm = prev.fetchFromGitHub {
          owner = "deepseek-ai";
          repo = "DeepGEMM";
          rev = "477618cd51baffca09c4b0b87e97c03fe827ef03";
          fetchSubmodules = true;
          hash = "sha256-7I1O9DDBGzij2NIjf8tQPFMCpTnyzMRdv1+bP3APOOc=";
        };
        # upgrade to the exact commit the nightly vllm pins:
        flash-attn-src = prev.applyPatches {
          src = prev.fetchFromGitHub {
            owner = "vllm-project";
            repo = "flash-attention";
            rev = "f5bc33cfc02c744d24a2e9d50e6db656de40611c";
            hash = "sha256-Bdvg5ROX4EFccrRElYnbGtHS9FD9qLY9ZwYfqTUYOnA=";
          };
          patches = [ ./flash-attn-skip-fa3-without-sm90.patch ];
        };
        # filter flags we're replacing so we don't pass duplicates
        dropFlag = prefix: prev.lib.filter (f: !(prev.lib.hasPrefix prefix f));
      in
      (dropFlag "-DVLLM_FLASH_ATTN_SRC_DIR"
       (dropFlag "-DTORCH_CUDA_ARCH_LIST"
        (dropFlag "-DCUTLASS_NVCC_ARCHS_ENABLED"
          oa.cmakeFlags)))
      ++ [
        "-DDEEPGEMM_SRC_DIR=${deepgemm}"
        "-DVLLM_FLASH_ATTN_SRC_DIR=${flash-attn-src}"
        "-DTORCH_CUDA_ARCH_LIST=8.6"
        "-DCUTLASS_NVCC_ARCHS_ENABLED=86"
      ];
    # trunk dropped grpcio-tools from pyproject.toml; strip the nixpkgs sed arg.
    postPatch = builtins.replaceStrings
      [ " \\\n  --replace-fail \"grpcio-tools==1.78.0\" \"grpcio\"" ]
      [ "" ]
      oa.postPatch;
    nativeBuildInputs = prev.lib.filter
      (p: !(prev.lib.hasInfix "runtime-deps-check" (p.name or "")))
      oa.nativeBuildInputs;
    # remove broken tokenspeed-mla/tokenspeed-triton from build inputs
    propagatedBuildInputs = prev.lib.filter
      (p: !(prev.lib.hasInfix "tokenspeed" (p.name or "")))
      (oa.propagatedBuildInputs or []);
    meta = { knownVulnerabilities = []; };
  });
in

{
  python313Packages = prev.python313Packages // {
    inherit flashinfer xgrammar;
    vllm = overriddenVllm;
  };
  inherit flashinfer;
  vllm = overriddenVllm;
}
