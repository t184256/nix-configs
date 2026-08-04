final: prev:

# override nixpkgs vllm (0.16.0) with 69b8956dc + dflash
#
# external cmake deps (CUDA only):
#   cutlass v4.2.1       - nixpkgs (via oa.cmakeFlags FETCHCONTENT_SOURCE_DIR)
#   FlashMLA 46d64a8e    - nixpkgs (via oa.cmakeFlags FLASH_MLA_SRC_DIR)
#                          trunk uses 692917b1; SM80 only reads interface.py
#                          (same path exists in both), compile skipped on SM80
#   qutlass 830d2c45     - nixpkgs (via oa.cmakeFlags QUTLASS_SRC_DIR), same rev
#   vllm-flash-attn f5bc33cf     - overridden below (nixpkgs has 2.7.2.post1)
#                          exact commit the nightly pins; has flash_attn/cute/
#                          csrc/cutlass is an empty submodule in the tarball;
#                          patch 0009 wires in FETCHCONTENT_SOURCE_DIR_CUTLASS
#                          patch 0010 skips FA3 target when no SM90+ archs
#   triton-kernels 3.6.0 - overridden below via env (nixpkgs has 3.5.0)
#   deepgemm 477618cd    - new in trunk; added below via cmakeFlags
#                          SM90+/SM100 compile only; SM80 gets empty target
#
# trunk moved opencv-python-headless, torchaudio, torchvision
# from optional-deps to required; all in cache.nixos-cuda.org, kept as-is.

let
  humming-kernels = prev.python313Packages.buildPythonPackage {
    pname = "humming-kernels";
    version = "0.1.2";
    format = "wheel";
    src = prev.fetchurl {
      url = "https://files.pythonhosted.org/packages/6d/41/288bf756d921dbe98982eeb3ec4c20e7cb5224ea6dcb164f2df3d2f68a7f/humming_kernels-0.1.2-py3-none-any.whl";
      hash = "sha256-90NLBCSUZEXvWtVoK8q/MJ2XchgY7VvcTG9h3jxrnS8=";
    };
    # torch/triton/numpy/safetensors/jinja2/tqdm are already provided by
    # vllm's propagatedBuildInputs; strip them to avoid a second copy.
    # nvidia-cuda-*: PyPI-wheel CUDA provisioning, replaced by NixOS cudaPackages.
    pythonRemoveDeps = [
      "torch" "triton" "numpy" "safetensors" "jinja2" "tqdm"
      "nvidia-cuda-runtime-cu12" "nvidia-cuda-cccl-cu12"
      "nvidia-cuda-nvcc-cu12" "nvidia-cuda-nvrtc-cu12"
      "nvidia-cuda-runtime" "nvidia-cuda-cccl"
      "nvidia-cuda-nvcc" "nvidia-cuda-nvrtc"
    ];
    propagatedBuildInputs = with prev.python313Packages; [
      cuda-bindings filelock nvidia-ml-py packaging pyelftools tabulate
    ];
    doCheck = false;
  };

  flashinfer = prev.python313Packages.flashinfer.overridePythonAttrs (oa: {
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
    # runtime-deps-check-hook fails on 0.6.8.post1 (can't find own metadata)
    nativeBuildInputs = prev.lib.filter
      (p: !(prev.lib.hasInfix "runtime-deps-check" (p.name or "")))
      oa.nativeBuildInputs;
    doCheck = false;
  });

  model-hosting-container-standards =
    prev.python313Packages."model-hosting-container-standards".overridePythonAttrs (_: {
      doCheck = false;
    });

  prometheus-fastapi-instrumentator = prev.python313Packages."prometheus-fastapi-instrumentator".overrideAttrs (oa: {
    version = "8.0.2";
    src = prev.fetchFromGitHub {
      owner = "trallnag";
      repo = "prometheus-fastapi-instrumentator";
      tag = "v8.0.2";
      hash = "sha256-fTJjAM1jUZXfhjLo9xqlu45LaoqZ330ogOA6x7aByqw=";
    };
    nativeBuildInputs = (oa.nativeBuildInputs or []) ++ [ prev.python313Packages.httpx2 ];
    disabledTestPaths = (oa.disabledTestPaths or []) ++ [
      "tests/test_instrumentator_included_router.py"
    ];
  });

  outlines = prev.python313Packages.outlines.overridePythonAttrs (_: {
    pythonRemoveDeps = [ "tensorflow" ];
  });

  overriddenVllm = (prev.python313Packages.vllm.override {
    inherit flashinfer prometheus-fastapi-instrumentator;
    inherit model-hosting-container-standards;
    inherit outlines;
  }).overrideAttrs (oa: {
    version = "0.23.0";
    src = prev.fetchFromGitHub {
      owner = "vllm-project";
      repo = "vllm";
      rev = "v0.23.0";
      hash = "sha256-9mxu2jLchoKmRzD71enPomVJuP5LjbUtQqLMdP5k+Qw=";
    };
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
           # PR #39995: FlashInfer DFlash fp8, per-layer headdim, SWA
           ./0012-dflash-swa.patch
           # SM86 GDN layers emit float32; cast before combine_hidden_states
           ./0013-dflash-cast-hidden-states-dtype.patch
           # MambaSpec: page_size_padded not derived from block_size
           ./0014-mamba-fp8-page-unify.patch
           # hybrid prefix-cache: GCD not raw LCM for hash_block_size
           ./0015-hybrid-coord-hash-block-gcd.patch
           # PR #40371: prompt_progress SSE events during prefill
           ./0016-prompt-progress-api.patch
           # PR #40783: Qwen3 reasoning parser fragmented <think> tag fixes
           ./0017-qwen3-reasoning-parser.patch
           # PR #40861: Qwen3Coder tool parser streaming fixes
           ./0018-qwen3-coder-tool-parser.patch
           # vllm:prefill_tokens_computed in-progress counter
           ./0019-prefill-tps-metric.patch
           # PR #39456: vllm:num_requests_prefilling/decoding gauges
           ./0020-prefill-decoding-req-gauges.patch
           # presence_penalty/frequency_penalty in generation_config defaults
           ./0021-generation-config-presence-penalty.patch
           # Disable Rust frontend - not needed for Nix builds
           ./0022-disable-rust-frontend.patch
           # PR #46231: defer offload reads while transfers are pending
           ./0023-defer-offload-reads-while-transfers-pending.patch
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
        SETUPTOOLS_SCM_PRETEND_VERSION = "0.19.0.dev20260514";
        VLLM_REQUIRE_RUST_FRONTEND = "0";
      };
    # TORCH_CUDA_ARCH_LIST must be set in preBuild, not env:
    # CUDA setup hooks from cudaPackages run after env is initialised and
    # override both. preBuild runs after all hooks, before cmake.
    # plum is RTX 3090 (SM86); don't set cudaCapabilities in pkgsCuda or
    # torch/flashinfer lose their binary cache hits.
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
        # cmake/external_projects/vllm_flash_attn.cmake GIT_TAG f5bc33cfc...
        # this version gates FA3/hopper kernels on CUDA_ARCHS containing SM90,
        # so they're skipped entirely for our SM86 build.
        # csrc/cutlass is an empty git submodule in the tarball; patch 0009
        # adds FETCHCONTENT_SOURCE_DIR_CUTLASS/include to the cmake targets.
        # patch skips FA3 when no SM90+ archs (API incompat with v4.2.1).
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
    propagatedBuildInputs = (oa.propagatedBuildInputs or [])
      ++ [ humming-kernels ];
    meta = { knownVulnerabilities = []; };
  });
in

{
  python313Packages = prev.python313Packages // {
    vllm = overriddenVllm;
    inherit prometheus-fastapi-instrumentator;
    inherit model-hosting-container-standards;
  };
  vllm = overriddenVllm;
}
