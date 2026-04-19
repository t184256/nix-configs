final: prev:
# Doesn't work with non-default python version

let
  newerVer = "8849";
  overrides-fresh = old: {
    name = "llama-cpp-${newerVer}";
    version = newerVer;
    src = prev.fetchFromGitHub {
      owner = "ggml-org";
      repo = "llama.cpp";
      tag = "b${newerVer}";
      hash = "sha256-SLiDrPcloriGIORvkuzUHCUpdr2Mt1Cm5NUQLZrXU8w=";
      leaveDotGit = true;
      postFetch = ''
        git -C "$out" rev-parse --short HEAD > $out/COMMIT
        find "$out" -name .git -print0 | xargs -0 rm -rf
      '';
    };
    npmDepsHash = "sha256-RAFtsbBGBjteCt5yXhrmHL39rIDJMCFBETgzId2eRRk=";
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

  llama-cpp-rocm-gfx1151 = llama-cpp-rocm.overrideAttrs (oa: {
    name = "llama-cpp-rocm-gfx1151-${newerVer}";
    patches = (oa.patches or []) ++ [
      # https://github.com/ggml-org/llama.cpp/pull/21344 slightly boosts PP,
      # and lowers TG, which I'm OK with for the slow-mo use case
      ./21344-gfx1151-optimization.patch
    ];
  });
in
{
  inherit llama-cpp llama-cpp-vulkan llama-cpp-rocm llama-cpp-rocm-gfx1151;
}
