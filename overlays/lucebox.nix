final: prev:

# Luce DFlash: speculative decoding for Qwen3.6-27B on RTX 3090.
# Builds the test_dflash C++/CUDA daemon and a Python server wrapper.
#
# Apply this overlay to a cuda-enabled nixpkgs instance (cudaSupport=true)
# so that prev.cudaPackages is populated. See nixos/services/lucebox.nix.
#
# Two submodules are fetched separately (tarballs lack submodule content):
#   deps/llama.cpp  → Luce-Org/llama.cpp-dflash-ggml@luce-dflash
#
# BSA (Block-Sparse-Attention) is disabled: its bundled cutlass submodule
# would need a separate nested fetch. The WMMA fallback on SM86 still
# gives fast speculative prefill. Re-enable with DFLASH27B_ENABLE_BSA=ON
# once the cutlass fetch is wired in.

let
  llama-cpp-dflash-src = prev.fetchFromGitHub {
    owner = "Luce-Org";
    repo = "llama.cpp-dflash-ggml";
    rev = "c79573c9b23980181c186b70812799f51e94fb50";
    hash = "sha256-bLKMQgrx/OJlyKcZWkm9ClxIYxTl1gglscI3s3snmog=";
  };

  # gguf-py ships inside the llama.cpp-dflash repo; build it so the server
  # can read GGUF metadata (arch, tokenizer name) at startup.
  gguf-py = prev.python3.pkgs.buildPythonPackage {
    pname = "gguf";
    version = "0.18.0";
    pyproject = true;
    src = "${llama-cpp-dflash-src}/gguf-py";
    build-system = [ prev.python3.pkgs."poetry-core" ];
    propagatedBuildInputs = with prev.python3.pkgs; [
      numpy tqdm pyyaml requests
    ];
  };

  pythonEnv = prev.python3.withPackages (ps: with ps; [
    fastapi
    uvicorn
    transformers
    datasets
    pydantic
    starlette
    jinja2
    gguf-py
  ]);

  dflash = prev.stdenv.mkDerivation {
    pname = "lucebox-dflash";
    version = "0-unstable-2026-05-11";

    src = prev.fetchFromGitHub {
      owner = "Luce-Org";
      repo = "lucebox-hub";
      rev = "d86472399d19300faed38086855a09e9fa2dc759";
      hash = "sha256-QiaYxVu/i8GJKgF1kixxOQk/i9HQbt5Cm5nZHqILB7w=";
    };

    sourceRoot = "source/dflash";

    # fetchFromGitHub tarballs have empty submodule dirs; fill them in.
    postUnpack = ''
      rm -rf source/dflash/deps/llama.cpp
      cp -r --no-preserve=mode ${llama-cpp-dflash-src} \
        source/dflash/deps/llama.cpp
    '';

    nativeBuildInputs = [
      prev.cmake
      prev.ninja
      prev.cudaPackages.cuda_nvcc
      prev.autoPatchelfHook
    ];

    buildInputs = [ prev.cudaPackages.cudatoolkit ];

    cmakeFlags = [
      # plum: dual RTX 3090, SM86
      "-DCMAKE_CUDA_ARCHITECTURES=86"
      # BSA is used only for PFlash speculative prefill (pflash=off in our
      # service). Also requires the Block-Sparse-Attention submodule with
      # bundled cutlass, which we don't fetch. No impact either way.
      "-DDFLASH27B_ENABLE_BSA=OFF"
      # OFF: ~3× faster build, locks KV to Q4_0/Q4_0 (the code default).
      # Flip to ON to unlock Q8_0 KV at runtime via DFLASH27B_KV_K/V envvars
      # (better quality on single-GPU where VRAM isn't the constraint).
      "-DDFLASH27B_FA_ALL_QUANTS=OFF"
      # ggml-cuda is a shared lib; embed $out/lib as RPATH from the start
      # so the installed binary never references the /build/ sandbox path.
      "-DCMAKE_INSTALL_RPATH=${placeholder "out"}/lib"
      "-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=FALSE"
      "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"
    ];

    # Build the inference daemon and the AR baseline binary (bench_llm.py
    # requires both to compare DFlash tok/s against autoregressive).
    # cmake configurePhase leaves us in sourceRoot; build dir is "build/".
    buildPhase = ''
      runHook preBuild
      cmake --build . --target test_dflash test_generate -j "$NIX_BUILD_CORES"
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin" "$out/lib" "$out/share/lucebox-dflash"
      # ggml-cuda (and friends) are shared libs; install them alongside the
      # binary so the RPATH ($out/lib) resolves at runtime.
      find . -name "libggml*.so*" -exec install -m755 {} "$out/lib/" \;
      install -m755 test_dflash "$out/bin/test_dflash"
      install -m755 test_generate "$out/bin/test_generate"
      # server.py does relative imports (_prefill_hook, prefix_cache) so
      # the entire scripts/ dir must land together.
      cp -r ../scripts "$out/share/lucebox-dflash/"
      runHook postInstall
    '';

    # Belt-and-suspenders: strip any /build/ sandbox entries that ggml's
    # own cmake might have embedded, then add $out/lib so libs find each
    # other. autoPatchelfHook re-adds real Nix store paths for libcudart etc.
    preFixup = ''
      for f in "$out/bin/test_dflash" "$out"/lib/*.so*; do
        [ -f "$f" ] || continue
        cur=$(patchelf --print-rpath "$f" 2>/dev/null) || continue
        new=$(printf '%s' "$cur" | tr ':' '\n' \
              | grep -v '/build/' | grep -v '^$' | paste -sd: -)
        patchelf --force-rpath --set-rpath "$new:$out/lib" "$f" || true
      done
    '';
  };

  # server.py uses relative imports from the scripts/ dir; inject PYTHONPATH
  # and the binary path so callers only need to supply model flags.
  server = prev.writeShellScriptBin "lucebox-dflash-server" ''
    scripts="${dflash}/share/lucebox-dflash/scripts"
    export PYTHONPATH="$scripts''${PYTHONPATH:+:$PYTHONPATH}"
    exec ${pythonEnv}/bin/python3 \
      "${dflash}/share/lucebox-dflash/scripts/server.py" \
      --bin "${dflash}/bin/test_dflash" \
      "$@"
  '';

in

{
  lucebox-dflash = dflash;
  lucebox-dflash-server = server;
}
