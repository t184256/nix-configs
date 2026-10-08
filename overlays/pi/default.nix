_: prev:

let
  newerVer = "1.1.0";
  freshSrc = prev.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${newerVer}";
    hash = "sha256-lwjspkMGrW+8Fl/yBEDEFsHZJA57OKOhmVQmi6zfej4=";
  };
  freshNpmDepsHash = "sha256-GOh5WG+rRgzoy/yVHY5PoEKJZGQcEGhISrDDJxkP8W4=";
  freshModelData = prev.fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${newerVer}.tgz";
    hash = "sha256-bKqzPOxXSA7QLFf+N0KKAwp3zCoGYoFLQ1pc+JMq2Ck=";
  };
  localPatches = [
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
    # Build workspace dependencies in order, then the coding-agent, using the
    # model catalog supplied via modelData instead of fetching it during build.
    # Remove when nixpkgs catches up to 1.1.0.
    buildPhase = ''
      runHook preBuild

      npm run build:offline

      runHook postBuild
    '';
    dontNpmPrune = true;
    preInstall = ''
      npm prune --omit=dev --no-save
    '';
    postInstall = ''
      local nm="$out/lib/node_modules/pi-monorepo/node_modules"

      # Replace workspace deps needed at runtime with real copies
      for ws in @earendil-works/chord:packages/chord \
                @earendil-works/pi-ai:packages/ai \
                @earendil-works/pi-agent-core:packages/agent \
                @earendil-works/pi-client:packages/client \
                @earendil-works/pi-codemode:packages/codemode \
                @earendil-works/pi-mcp:packages/mcp \
                @earendil-works/pi-protocol:packages/protocol \
                @earendil-works/pi-telemetry:packages/telemetry \
                @earendil-works/pi-tui:packages/tui; do
        IFS=: read -r pkg src <<< "$ws"
        rm "$nm/$pkg"
        cp -r "$src" "$nm/$pkg"
      done

      # Delete remaining workspace symlinks
      find "$nm" -type l -lname '*/packages/*' -delete

      # Clean up now-dangling .bin symlinks
      find "$nm/.bin" -xtype l -delete
    '';
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
