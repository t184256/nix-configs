{ inputs, pkgs, lib, config, ... }:

# Two manually-started services mirroring the vllm.nix setup:
# compare Qwen3.5-9B AWQ with and without DFlash on the same port.
# All four services (vllm{,-dflash}, sglang{,-dflash}) conflict —
# only one can hold the GPU at a time.
#
#   systemctl start sglang          # plain AWQ
#   systemctl start sglang-dflash   # AWQ + DFlash speculation
# Both on port 8002.
#
# Package: flox/sglang-dev — pre-built CUDA wheels for SM75-SM120.
# Binary cache: flox builds are not on cache.nixos-cuda.org;
#   build on grapefruit and push to plum similarly to vllm,
#   or wait for a public flox cache URL.

let
  # The per-variant .nix files in flox/sglang-dev call builtins.fetchTarball
  # without sha256, which is banned in pure eval mode.
  # Their lib/ files are fine (fetchurl with sha256 throughout).
  # Bypass the wrappers entirely: call lib files directly with our nixpkgs,
  # configured for SM86 + CUDA 12.8.
  flox = "${inputs.sglang-dev}/.flox/pkgs/lib";
  sgPkgs = import inputs.nixpkgs-sglang {
    system = pkgs.system;
    config = {
      allowUnfree = true;
      cudaSupport = true;
      cudaCapabilities = [ "8.6" ];
    };
    overlays = [
      (final: _: { cudaPackages = final.cudaPackages_12_8; })
    ];
  };
  buildMeta = builtins.fromJSON
    (builtins.readFile "${inputs.sglang-dev}/build-meta/sglang.json");
  cpuISA = (import "${flox}/cpu-isa.nix").avx512;
  python312Custom = sgPkgs.python312.override {
    packageOverrides = final: super: {
      torch = import "${flox}/custom-torch.nix" {
        inherit (sgPkgs) lib;
        torchBase = super.torch;
        smCapability = "8.6";
        inherit cpuISA;
        platform = "x86_64-linux";
        cudaVersionTag = "cuda12_8";
      };

      # sglang 0.5.9 ecosystem (transformers 4.57.6, compressed-tensors,
      # torchao, …) all require huggingface-hub<1.0; nixpkgs ships 1.9.0.
      # Pin to the last 0.x release — self-contained within sgPkgs.
      huggingface-hub = final.buildPythonPackage rec {
        pname = "huggingface-hub";
        version = "0.36.2";
        format = "wheel";
        src = builtins.fetchurl {
          url = "https://files.pythonhosted.org/packages/a8/af/48ac8483240de756d2438c380746e7130d1c6f75802ef22f3c6d49982787/huggingface_hub-0.36.2-py3-none-any.whl";
          sha256 = "sha256-SPDI6sFhRd/ONx6dLXdyhUpPWRvLVsnPVIrM9THVQnA=";
        };
        pythonRemoveDeps = true;
        propagatedBuildInputs = with super; [
          filelock fsspec packaging
          pyyaml requests tqdm typing-extensions
        ];
        pythonImportsCheck = [ ];
      };

      # torchao's test suite requires huggingface-hub<1.0 but nixpkgs
      # ships 1.9.0 — just skip tests, we only need the runtime package.
      torchao = super.torchao.overrideAttrs (_: { doCheck = false; });

      # SGLang 0.5.9 targets transformers 4.57.6.
      # 4.58+ applies @dataclass to PretrainedConfig subclasses, which
      # breaks DeepseekVL2Config (non-default field after default field).
      transformers = final.buildPythonPackage rec {
        pname = "transformers";
        version = "4.57.6";
        format = "wheel";
        src = builtins.fetchurl {
          url = "https://files.pythonhosted.org/packages/03/b8/e484ef633af3887baeeb4b6ad12743363af7cce68ae51e938e00aaa0529d/transformers-4.57.6-py3-none-any.whl";
          sha256 = "sha256-TJ6d4RMz3f5RFLyHLJ83BQkZis8Lh6gyoKuUWOK9BVA=";
        };
        pythonRemoveDeps = true;
        propagatedBuildInputs = with final; [
          filelock huggingface-hub numpy packaging
          pyyaml regex requests safetensors tokenizers tqdm
        ];
        pythonImportsCheck = [ ];
      };
    };
  };
  sgl-kernel = import "${flox}/sgl-kernel.nix" {
    python3 = python312Custom;
    inherit (sgPkgs) cudaPackages autoPatchelfHook stdenv numactl;
  };
  flashinfer =
    let fi = import "${flox}/flashinfer.nix" {
          python3 = python312Custom;
          inherit (sgPkgs) cudaPackages autoPatchelfHook stdenv;
        };
    in fi // {
      # flashinfer-python wheel lists optional deps (click, einops,
      # nvidia-cutlass-dsl, …) in Requires-Dist that aren't needed for
      # core serving; strip all wheel dep metadata like sglang-pkg does.
      flashinfer-python = fi.flashinfer-python.overrideAttrs (_: {
        pythonRemoveDeps = true;
      });
    };
  xgrammar = (import "${flox}/xgrammar.nix" {
    python3 = python312Custom;
    inherit (sgPkgs) autoPatchelfHook stdenv;
  }).overrideAttrs (_: {
    # xgrammar wheel lists transformers in Requires-Dist but uses it
    # only optionally; strip all wheel dep metadata like sglang-pkg does.
    pythonRemoveDeps = true;
  });
  sglangPkg = (import "${flox}/sglang-pkg.nix" {
    python3 = python312Custom;
    inherit sgl-kernel xgrammar;
    flashinfer-python = flashinfer.flashinfer-python;
  }).overrideAttrs (old: {
    pname = "sglang-python312-cuda12_8-sm86-avx512";
    version = "0.5.10-post+${buildMeta.git_rev_short}";
    __intentionallyOverridingVersion = true;
  });

  # buildPythonPackage produces a site-packages tree, not a Python
  # interpreter. withPackages wires up PYTHONPATH and gives us bin/python3.12.
  pythonEnv = python312Custom.withPackages (_: [ sglangPkg ]);

  model = pkgs.qwen35-9b-awq;
  draft = pkgs.qwen35-9b-dflash-draft;

  # Match vllm.nix values for a fair comparison.
  maxModelLen       = 262144;
  maxModelLenDFlash = 61440;
  numDraftTokens    = 3;

  commonEnv = [
    "LD_LIBRARY_PATH=/run/opengl-driver/lib"
    # tvm_ffi / Triton JIT build C++ extensions at runtime via ninja;
    # use explicit compiler paths so wheel-embedded paths don't break on NixOS.
    "CC=${pkgs.gcc}/bin/gcc"
    "CXX=${pkgs.gcc}/bin/g++"
    # awq_marlin triggers Triton JIT during CUDA graph capture; Triton needs
    # CUDA_HOME to find nvcc/headers.
    "CUDA_HOME=${sgPkgs.cudaPackages.cudatoolkit}"
    # tvm_ffi build.ninja omits -I for CUDA headers; supply them via the
    # host-compiler search path so nvcc finds cuda_runtime.h, nv/target, etc.
    "CPLUS_INCLUDE_PATH=${sgPkgs.cudaPackages.cudatoolkit}/include"
    # tvm_ffi build.ninja links -lcudart via -L${cuda-merged}/lib64, but the
    # unversioned libcudart.so stub is in cuda_cudart/lib/stubs in split pkgs.
    "LIBRARY_PATH=${sgPkgs.cudaPackages.cuda_cudart}/lib"
    "PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True"
    "SGLANG_DISABLE_CUDNN_CHECK=1"
    # cubin is 0.6.8.post1, flashinfer-python wheel is 0.6.8; no .post1 on PyPI
    "FLASHINFER_DISABLE_VERSION_CHECK=1"
    # AWQ requires float16; align conv states to avoid scalar_type mismatch
    # in sgl_kernel causal_conv1d_fwd (default is bfloat16).
    "SGLANG_MAMBA_CONV_DTYPE=float16"
    # Triton and FlashInfer write JIT artefacts; redirect away from
    # /var/empty (the default system-user home).
    "TRITON_CACHE_DIR=/var/lib/sglang/triton"
    "FLASHINFER_CACHE_DIR=/var/lib/sglang/flashinfer"
  ];

  plainScript = pkgs.writeShellScript "sglang-plain" ''
    exec ${pythonEnv}/bin/python3.12 -m sglang.launch_server \
      --model-path ${model} \
      --quantization awq_marlin \
      --dtype float16 \
      --context-length ${toString maxModelLen} \
      --mem-fraction-static 0.85 \
      --host 127.0.0.1 --port 8002
  '';

  # DFlash: source is now commit 43925d1 (2026-04-15), which includes both
  # f08726fd5 (DFlash algorithm) and c3833ba92 (Qwen3.5 DFlash support).
  # --trust-remote-code needed for dflash.py in the draft model dir.
  # --speculative-dflash-draft-window-size omitted: inferred from config.json.
  # If FlashInfer JIT fails on SM86, add: --attention-backend triton
  dflashScript = pkgs.writeShellScript "sglang-dflash" ''
    exec ${pythonEnv}/bin/python3.12 -m sglang.launch_server \
      --model-path ${model} \
      --quantization awq_marlin \
      --dtype float16 \
      --context-length ${toString maxModelLenDFlash} \
      --mem-fraction-static 0.75 \
      --speculative-algorithm DFLASH \
      --speculative-draft-model-path ${draft} \
      --speculative-num-draft-tokens ${toString numDraftTokens} \
      --trust-remote-code \
      --mamba-scheduler-strategy extra_buffer \
      --speculative-draft-model-quantization unquant \
      --max-running-requests 1 \
      --speculative-dflash-draft-window-size 4096 \
      --host 127.0.0.1 --port 8002
  '';

  commonService = {
    after = [ "multi-user.target" ];
    path = [ config.hardware.nvidia.package pkgs.gcc pkgs.ninja
             sgPkgs.bash  # realize sgPkgs bash; CUDA wrapper shebangs ref it
             sgPkgs.cudaPackages.cudatoolkit
             sgPkgs.cudaPackages.cuda_nvcc ];  # ptxas for Triton JIT
    serviceConfig = {
      User = "sglang";
      Group = "sglang";
      Environment = commonEnv;
      PrivateDevices = false;
      PrivateTmp = true;
      ProtectHome = true;
      StateDirectory = "sglang";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

in

{
  environment.persistence."/mnt/persist".directories =
    [ "/var/lib/sglang" ];

  systemd.services.sglang = lib.recursiveUpdate commonService {
    description = "sglang: Qwen3.5-9B AWQ (plain)";
    unitConfig.Conflicts = "vllm.service vllm-dflash.service";
    serviceConfig.ExecStart = plainScript;
  };

  systemd.services.sglang-dflash = lib.recursiveUpdate commonService {
    description = "sglang: Qwen3.5-9B AWQ + DFlash speculative decoding";
    unitConfig.Conflicts =
      "sglang.service vllm.service vllm-dflash.service";
    serviceConfig.ExecStart = dflashScript;
    serviceConfig.Environment =
      commonService.serviceConfig.Environment
      ++ [ "SGLANG_ENABLE_SPEC_V2=1" ];
  };

  users.groups.sglang = { };
  users.users.sglang = {
    isSystemUser = true;
    group = "sglang";
    extraGroups = [ "video" "render" ];
    # systemd sets HOME before triton/flashinfer init their cache dirs
    home = "/var/lib/sglang";
  };

  networking.firewall.allowedTCPPorts = [ 8002 ];
}
