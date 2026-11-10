_: prev:

let
  newerVer = "1.5.2";
  freshSrc = prev.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${newerVer}";
    # Hash of the github.com/.../archive/... tarball as fetched by nix,
    # which differs from the codeload.github.com copy of the same tag.
    hash = "sha256-0dKtABQqfvCLF0WOydu5rpycMqC+N8Pc9Ex4BWKElyw=";
  };
  freshNpmDepsHash = "sha256-uHehffbEB2uU9U9uSpfWojzxvQyqeicbh/esCwk4neQ=";
  freshModelData = prev.fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${newerVer}.tgz";
    hash = "sha256-1XFe+oNMI7/fEKBCtJ307hacyZAAvxbXmY+rLVM7Rfg=";
  };
  localPatches = [
    ./9709-bandaid.patch

    ./rich-exec-suppress-upstream.patch
    ./rich-exec-exit-code.patch
    ./rich-exec-openai.patch
    ./rich-exec-tui.patch

    ./compact-01-edit-spacers.patch
    ./compact-02-interactive-spacers.patch
    ./compact-03-interactive-depad.patch
    ./compact-04-interactive-noborder.patch
    ./compact-05-user-message-depad.patch
    ./compact-06-custom-message-depad.patch
    ./compact-07-tool-execution-spacers-padding.patch
    ./compact-08-bash-execution-spacers-newlines.patch
    ./compact-09-tools-bash-newlines.patch
    ./compact-10-edit-depad.patch
    ./compact-11-footer-no-auto.patch
    ./compact-12-footer-model.patch
    ./compact-13-tui-loader-depad-border-status.patch
    ./compact-14-editor-noborder.patch
    ./compact-15-tool-execution-depad.patch
    ./compact-16-assistant-message-spacers.patch
    ./compact-17-assistant-message-depad.patch
    ./compact-18-footer-one-line.patch
    ./compact-19-editor-background.patch
    ./compact-20-fullscreen-editor-minsize.patch
    ./compact-21-footer-preserve-model.patch
    ./compact-22-bash-execution-noborder.patch
    ./compact-23-footer-routed-model.patch
    ./compact-24-bash-spacers.patch

    ./clipboard-primary-selection.patch
    ./fullscreen-clipboard-paste.patch
    ./fullscreen-scrollbar-away.patch
  ];
  overrides-fresh = oa: {
    version = newerVer;
    src = freshSrc;
    npmDepsHash = freshNpmDepsHash;
    modelData = freshModelData;
    # preConfigure interpolates modelData when the original derivation is
    # built, so it must be overridden alongside modelData.
    preConfigure = ''
      mkdir -p packages/ai/src/providers/data
      tar --extract --gzip --file=${freshModelData} \
        --directory=packages/ai/src/providers/data \
        --strip-components=4 \
        package/dist/providers/data
    '';
    # the npmDeps sub-derivation needs to be updated as well
    npmDeps = oa.npmDeps.overrideAttrs (_: {
      name = "pi-coding-agent-${newerVer}-npm-deps";
      src = freshSrc;
      outputHash = freshNpmDepsHash;
      patches = localPatches;
    });
  };
  overrides-patches = oa: {
    patches = (oa.patches or []) ++ localPatches;
  };
  pi-coding-agent = prev.pi-coding-agent.overrideAttrs (
    if prev.lib.versionAtLeast prev.pi-coding-agent.version newerVer
    then overrides-patches
    else (oa: (overrides-fresh oa) // (overrides-patches oa))
  );
in
{ inherit pi-coding-agent; }
