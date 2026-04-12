final: prev:
# Doesn't work with non-default python version

let
  newerVer = "8744";
  overrides-fresh = old: {
    name = "llama-cpp-${newerVer}";
    version = newerVer;
    src = prev.fetchFromGitHub {
      owner = "ggml-org";
      repo = "llama.cpp";
      tag = "b${newerVer}";
      hash = "sha256-xLsJ8FjDzneyXlGXuGF5RV4xo3VHkMjNRGVPxS5Ihf0=";
      leaveDotGit = true;
      postFetch = ''
        git -C "$out" rev-parse --short HEAD > $out/COMMIT
        find "$out" -name .git -print0 | xargs -0 rm -rf
      '';
    };
    npmDepsHash = "sha256-eeftjKt0FuS0Dybez+Iz9VTVMA4/oQVh+3VoIqvhVMw=";
    # add stub tools/server/public/index.html.gz to pacify upstream patchPhase
    prePatch = (old.prePatch or "") + ''
      mkdir -p tools/server/public
      touch tools/server/public/index.html.gz
    '';
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
