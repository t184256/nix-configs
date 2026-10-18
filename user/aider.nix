{ pkgs, config, lib, ... }:

let
  ctx196k = 196608;
  ctx256k = 262144;
  ctx128k = 128000;

  mkModel = extra: ctx: name:
    let fullName = "hosted_vllm/${name}"; in {
      alias = "${name}:${fullName}";
      settings = {
        name = fullName;
        edit_format = "editor-diff";
        use_repo_map = true;
        streaming = true;
      } // extra;
      meta."${fullName}" = {
        max_input_tokens = ctx;
        max_output_tokens = ctx;
        max_tokens = ctx;
        #mode = "chat";
        #supports_function_calling = true;
        #supports_tool_choice = true;
      };
    };

  # sampling params injected by LiteLLM, don't override here
  mkPlum = mkModel {} ctx196k;
  mkGrapefruit = mkModel {} ctx256k;
  mkMini = mkModel {} ctx128k;

  # only what slop-forward actually serves (litellm has no catchall anymore)
  models = {
    "default" = mkGrapefruit;      # qwen3.8-flash-next, thinking on
    "qwen3.8-27b-nothink" = mkPlum;
    "qwen3.8-27b-think" = mkPlum;
    "mini" = mkMini;               # LFM2.5-8B-A2B, grapefruit's mini unit
  };

  modelSettings = builtins.toJSON (
    builtins.attrValues (builtins.mapAttrs (n: mk: (mk n).settings) models)
  );
  modelMetadata = builtins.toJSON (
    builtins.foldl' (a: b: a // b) {}
      (builtins.attrValues (builtins.mapAttrs (n: mk: (mk n).meta) models))
  );

  modelSettingsFile = pkgs.writeText "aider.model.settings.json" modelSettings;
  modelMetadataFile = pkgs.writeText "aider.model.metadata.json" modelMetadata;
  aiderPkg = if config.system.noGraphics
    then pkgs.aider-chat
    else pkgs.aider-chat-with-playwright;
in
{
  imports = [ ./config/roles.nix ./config/no-graphics.nix ];

  nixpkgs.overlays = lib.mkIf config.roles.slop [ (import ../overlays/aider) ];

  programs.aider-chat = {
    enable = lib.mkDefault false;
    package = null;
    settings = {
      model = "default";
      editor-model = "mini";
      weak-model = "mini";
      architect = true;
      alias = builtins.attrValues (
        builtins.mapAttrs (n: mk: (mk n).alias) models
      );
      vim = true;
      dark-mode = true;
      watch-files = true;
      map-tokens = 2048;
      auto-commits = false;
      stream = true;
      analytics-disable = true;
      check-update = false;
      gitignore = false;
      show-release-notes = false;
      show-model-warnings = false;
      model-settings-file = "${modelSettingsFile}";
      model-metadata-file = "${modelMetadataFile}";
      chat-history-file = "${config.xdg.stateHome}/nvim/aider-chat-history.md";
      input-history-file = "${config.xdg.stateHome}/nvim/aider-input-history";
      #auto-test = true;
      #test-cmd = "";
      #git-commit-verify = true;
    };
  };

  home.packages = lib.mkIf (config.roles.slop && config.programs.aider-chat.enable) [
    (pkgs.symlinkJoin {
      name = "aider";
      paths = [ aiderPkg ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/aider \
          --run 'export OPENAI_API_KEY="$(cat /mnt/secrets/whisper)"' \
          --set OPENAI_API_BASE "https://whisper.slop.unboiled.info/v1" \
          --run 'export HOSTED_VLLM_API_KEY="$(cat /mnt/secrets/llm)"' \
          --set HOSTED_VLLM_API_BASE "https://llm.slop.unboiled.info/v1"
      '';
    })
  ];
}
