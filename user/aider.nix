{ pkgs, config, ... }:

let
  ctx128k = 131072;
  ctx256k = 262144;

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

  mkGptOss = mkModel { accepts_settings = [ "reasoning_effort" ]; } ctx128k;
  # https://unsloth.ai/docs/models/nemotron-3/nemotron-3-super (tool calling)
  mkNemotron = mkModel {
    use_temperature = 0.6;
    extra_params = {
      top_p = 0.95; min_p = 0.01;
    };
  } ctx128k;
  # https://unsloth.ai/docs/models/qwen3.5 (thinking:general)
  mkQwen = mkModel {
    accepts_settings = [ "thinking" ];
    use_temperature = 1.0;
    extra_params = {
      top_p = 0.95; top_k = 20; min_p = 0.0; presence_penalty = 1.5;
    };
  } ctx256k;
  # https://unsloth.ai/docs/models/qwen3.5 (instruct:general)
  mkQwenQuick = mkModel {
    accepts_settings = [ "thinking" ];
    use_temperature = 0.7;
    extra_params = {
      top_p = 0.8; top_k = 20; min_p = 0.0; presence_penalty = 1.5;
      extra_body.chat_template_kwargs.enable_thinking = false;
    };
  } ctx256k;

  models = {
    "gpt-oss:120b" = mkGptOss;
    "gpt-oss:20b" = mkGptOss;
    "nemotron-super" = mkNemotron;
    "qwen3.5-coder-sparse" = mkQwen;
    "qwen3.5-coder-dense" = mkQwen;
    "qwen3.5-coder-sparse-quick" = mkQwenQuick;
    "qwen3.5-coder-dense-quick" = mkQwenQuick;
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
  imports = [ ./config/no-graphics.nix ];

  nixpkgs.overlays = [ (import ../overlays/aider) ];

  programs.aider-chat = {
    enable = true;
    package = null;
    settings = {
      model = "qwen3.5-coder-sparse";
      editor-model = "qwen3.5-coder-sparse-quick";
      weak-model = "qwen3.5-coder-sparse-quick";
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

  home.packages = [
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
