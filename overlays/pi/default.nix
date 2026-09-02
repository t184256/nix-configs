_: prev:

let
  newerVer = "0.84.4";
  freshSrc = prev.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${newerVer}";
    hash = "sha256-7z8OXao1PzmBEepDkIqVqyfQBPHulBlKcGymDYsnMvc=";
  };
  freshNpmDepsHash = "sha256-35GC3Q4Jf4URvqoEYHeM63x49tTmrth62//PvKm4I7Q=";
  freshModelData = prev.fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${newerVer}.tgz";
    hash = "sha256-39PJKc7lpzhxmaCiTfwb4glvHqj1n/uChRmKDtAev5M=";
  };
  localPatches = [
    ./compact-01-edit-spacers.patch
    ./compact-02-interactive-spacers.patch
    ./compact-03-interactive-depad.patch
    ./compact-04-interactive-noborder.patch
    ./compact-05-user-message-depad.patch
    ./compact-06-custom-message-depad.patch
    ./compact-07-tool-execution-spacers.patch
    ./compact-08-tool-execution-depad.patch
    ./compact-09-bash-execution-spacers.patch
    ./compact-10-bash-execution-depad.patch
    ./compact-11-bash-execution-simplify.patch
    ./compact-12-assistant-message-spacers.patch
    ./compact-13-assistant-message-depad.patch
    ./compact-14-tools-bash-newlines.patch
    ./compact-15-edit-depad.patch
    ./compact-16-footer-no-auto.patch
    ./compact-18-footer-one-line.patch
    ./compact-19-loader.patch
    ./compact-20-editor-noborder.patch
    ./compact-21-editor-background.patch
    ./compact-22-fullscreen-editor-minsize.patch
    ./compact-23-footer-preserve-model.patch

    ./success-completion.patch

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
    # The build/install phases changed between 0.83.0 and 0.84.2.
    # Remove when nixpkgs catches up to 0.84.2.
    buildPhase = ''
      runHook preBuild

      npx tsgo -p packages/tui/tsconfig.build.json
      npx tsgo -p packages/telemetry/tsconfig.build.json
      npx tsgo -p packages/ai/tsconfig.build.json
      npx tsgo -p packages/agent/tsconfig.build.json
      npx tsgo -p packages/protocol/tsconfig.build.json
      npx tsgo -p packages/client/tsconfig.build.json
      npm run build --workspace=packages/coding-agent

      runHook postBuild
    '';
    dontNpmPrune = true;
    preInstall = ''
      npm prune --omit=dev --no-save
    '';
    postInstall = ''
      local nm="$out/lib/node_modules/pi-monorepo/node_modules"

      # Replace workspace deps needed at runtime with real copies
      for ws in @earendil-works/pi-ai:packages/ai \
                @earendil-works/pi-agent-core:packages/agent \
                @earendil-works/pi-client:packages/client \
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
