final: prev:
# Doesn't work with non-default python version

let
  newerVer = "8429";
  overrides-fresh = _: {
    name = "llama-cpp-${newerVer}";
    version = newerVer;
    src = prev.fetchFromGitHub {
      owner = "ggml-org";
      repo = "llama.cpp";
      tag = "b${newerVer}";
      hash = "sha256-yrE+8h7RxRttMyBs3dlJQ+NEnO65ZIsl/CArnjdOfFU=";
      leaveDotGit = true;
      postFetch = ''
        git -C "$out" rev-parse --short HEAD > $out/COMMIT
        find "$out" -name .git -print0 | xargs -0 rm -rf
      '';
    };
    npmDepsHash = "sha256-DxgUDVr+kwtW55C4b89Pl+j3u2ILmACcQOvOBjKWAKQ=";
  };
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
in
{
  inherit llama-cpp llama-cpp-vulkan llama-cpp-rocm;
}
