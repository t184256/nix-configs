final: prev:

# override nixpkgs vllm (0.16.0) with a trunk commit (2026-05-10) that
# has dflash.
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
# trunk moved opencv-python-headless, mistral-common, torchaudio, torchvision
# from optional-deps to required; all in cache.nixos-cuda.org, kept as-is.
# mistral-common: trunk requires >= 1.11.0; nixpkgs has 1.8.8 (NamedToolChoice
# was added in 1.11.0); overridden below.

let
  flashinfer = prev.python3Packages.flashinfer.overrideAttrs (oa: {
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
      ++ [ prev.python3Packages.apache-tvm-ffi ];
    # cuda-tile is listed in requirements.txt but never imported; requires
    # CUDA 13.1+ which we don't have. Strip it like nixpkgs strips cutlass-dsl.
    pythonRemoveDeps = (oa.pythonRemoveDeps or []) ++ [ "cuda-tile" ];
  });

  mistral-common = prev.python3Packages.mistral-common.overrideAttrs (oa: {
    version = "1.11.0";
    src = prev.fetchFromGitHub {
      owner = "mistralai";
      repo = "mistral-common";
      tag = "v1.11.0";
      hash = "sha256-DejbLY2i6Hp1J+spxMut5RKugj7rDyrZmp6v+5wqyWY=";
    };
    # tests/guidance/ requires llguidance, not in nixpkgs
    disabledTestPaths = (oa.disabledTestPaths or []) ++ [ "tests/guidance" ];
  });

  overriddenVllm = (prev.python3Packages.vllm.override {
    inherit mistral-common flashinfer;
  }).overrideAttrs (oa: {
    version = "0-unstable-2026-05-10";
    src = prev.fetchFromGitHub {
      owner = "vllm-project";
      repo = "vllm";
      rev = "5cba6839e6cb8ede0c81947557b76617468d0d61";
      hash = "sha256-b394oOuvvWgPHOYLfHhB93GByfmPnkfJUY/prMy8Spk=";
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
           # SM86 GDN layers emit float32; cast before combine_hidden_states
           ./0011-dflash-cast-hidden-states-dtype.patch
           # PR #39995: FlashInfer DFlash fp8, per-layer headdim, SWA
           ./0012-dflash-swa.patch
           # MambaSpec: page_size_padded not derived from block_size
           ./0013-mamba-fp8-page-unify.patch
           # VL model: input_ids=None breaks AOT shape guards; substitute zeros
           # (incomplete)
           ./0014-zero-modality-limits.patch
           # hybrid prefix-cache: GCD not raw LCM for hash_block_size
           ./0015-hybrid-coord-hash-block-gcd.patch
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
        SETUPTOOLS_SCM_PRETEND_VERSION = "0.19.0.dev20260510";
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
        # patch 0010 skips FA3 when no SM90+ archs (API incompat with v4.2.1).
        flash-attn-src = prev.applyPatches {
          src = prev.fetchFromGitHub {
            owner = "vllm-project";
            repo = "flash-attention";
            rev = "f5bc33cfc02c744d24a2e9d50e6db656de40611c";
            hash = "sha256-Bdvg5ROX4EFccrRElYnbGtHS9FD9qLY9ZwYfqTUYOnA=";
          };
          patches = [ ./0010-flash-attn-skip-fa3-without-sm90.patch ];
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
  });
in

{
  python3Packages = prev.python3Packages // {
    inherit mistral-common;
    vllm = overriddenVllm;
  };
  vllm = overriddenVllm;
}
