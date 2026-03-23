final: prev: {
  ik-llama-cpp = prev.llama-cpp.overrideAttrs (oa: {
    pname = "ik-llama-cpp";

    src = prev.fetchFromGitHub {
      owner = "ikawrakow";
      repo = "ik_llama.cpp";
      rev = "56e026f6ba53b7521094228bebfe16b97aaf2ba8";
      hash = "sha256-FQfbkAzWDzKaxvUdRPp4aBEs/BJTKkYjMmKWyJwYyVc=";
      leaveDotGit = true;
      postFetch = ''
        git -C "$out" rev-parse --short HEAD > $out/COMMIT
        find "$out" -name .git -print0 | xargs -0 rm -rf
      '';
    };

    # no npm
    npmDepsHash = null;
    npmDeps = null;
    npmRoot = null;
    nativeBuildInputs = prev.lib.filter (
      p: p != prev.nodejs && p.name != prev.npmHooks.npmConfigHook.name
    ) oa.nativeBuildInputs;
    preConfigure = ''
      prependToVar cmakeFlags "-DBUILD_COMMIT:STRING=$(cat COMMIT)"
    '';
    postPatch = "";

    # LLAMA_BUILD_NUMBER -> BUILD_NUMBER
    # LLAMA_BUILD_EXAMPLES disabled upstream, but server lives under examples
    # GGML_HIP -> GGML_HIPBLAS
    cmakeFlags = prev.lib.concatMap (f:
      if prev.lib.hasPrefix "-DLLAMA_BUILD_NUMBER" f then []
      else if prev.lib.hasPrefix "-DLLAMA_BUILD_EXAMPLES" f then []
      else if prev.lib.hasPrefix "-DGGML_HIP:" f
        then [
          (builtins.replaceStrings [ "-DGGML_HIP:" ] [ "-DGGML_HIPBLAS:" ] f)
        ]
        else [ f ]
    ) oa.cmakeFlags
    ++ [
      (prev.lib.cmakeFeature "BUILD_NUMBER" oa.version)
      (prev.lib.cmakeBool "LLAMA_BUILD_EXAMPLES" true)
    ];
  });

  ik-llama-cpp-vulkan = final.ik-llama-cpp.override { vulkanSupport = true; };
  ik-llama-cpp-rocm = final.ik-llama-cpp.override { rocmSupport = true; };
}
