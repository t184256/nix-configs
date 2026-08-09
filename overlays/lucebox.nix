# env LD_LIBRARY_PATH=/run/opengl-driver/lib dflash_server Qwen3.6-27B-NOMTP-Q4_K_M.gguf --draft lucebox/dflash-draft-3.6-q4_k_m.gguf --max-ctx 262144 --target-devices cuda:0,cuda:1 --target-split-mode tensor --peer-access --draft-residency persistent


#--- thinking=False ---
#target      pp      ttft   pp tps   decode tps    gen
#   256     274    0.483s      568         61.8    128
#  8192    8203    7.839s     1046         52.8    128
# 16384   16386   15.923s     1029         51.2    128
# 32768   32752   33.041s      991         43.6    128
# 65536   65483   71.339s      918         38.5    128
#131072  130946  164.471s      796         34.1    128
#196608  196408  280.996s      699         31.5    128
#262144  261679  429.456s      609         23.3    128

final: prev:

{
  lucebox = prev.stdenv.mkDerivation rec {
    pname = "lucebox";
    version = "0.1.0";

    # TODO: switch to fetchFromGitHub once network is available
    # and compute proper sha256 hash. Block-Sparse-Attention submodule
    # is optional (BSA auto-disables without it).
    #src = builtins.fetchTree {
    #  type = "git";
    #  url = "file:///home/sloppy/workspace/lucebox";
    #};
    src = prev.fetchFromGitHub {
      owner = "Luce-Org";
      repo = "lucebox";
      rev = "22b4ad1977686de3804a24f3e32c2ed860fe6cea";
      sha256 = "sha256-CM/OgzOAZ90wFzNrr2vEm/hyWDUc28qjPsgUSes4e0s=";
    };

    sourceRoot = "source/server";

    nativeBuildInputs = with prev; [
      cmake ninja cudatoolkit nlohmann_json
    ];

    buildInputs = with prev.cudaPackages; [ cudatoolkit ]
      ++ [ (prev.lib.getLib prev.stdenv.cc.cc) ]
      ++ (with prev; prev.lib.optionals prev.stdenv.cc.isClang
           [ prev.llvmPackages.openmp ]);

    cmakeFlags = [
      # RTX 3090 = Ampere sm_86
      "-DDFLASH27B_USER_CUDA_ARCHITECTURES=86"
      # BSA needs Block-Sparse-Attention submodule + breaks pflash on dual-GPU
      "-DDFLASH27B_ENABLE_BSA=OFF"
      # Avoid build-time /build/ RPATH references
      "-DCMAKE_SKIP_BUILD_RPATH=ON"
      "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"
    ];

    doCheck = false;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin" "$out/share/model_cards"
      # cmake build dir is PWD; binaries are here
      cp dflash_server test_dflash "$out/bin/"
      # Prune deps tree to only .so files (like Dockerfile does)
      cp --recursive deps "$out/"
      find "$out/deps" -type f ! -name 'lib*.so*' -delete
      find "$out/deps" -depth -type d -empty -delete
      # model cards are in source tree sibling of server/
      cp ../../share/model_cards/* "$out/share/model_cards/"
      runHook postInstall
    '';

    meta = with prev.lib; {
      description = "Open LLM inference engine rewritten for specific GPU architectures";
      homepage = "https://github.com/Luce-Org/lucebox";
      license = licenses.asl20;
      platforms = platforms.linux;
    };
  };
}
