{ pkgs, config, lib, ... }:

let
  ctx128k = 131072;
  ctx256k = 262144;

  consumptionW = 100; # Electricity-based cost model, assuming 100W consumption
  USDperWs = 5.0e-8; # 0.15 USD/KWh = 0.15 / (3600 * 1000) USD/Ws = ~5e-8 USD/Ws
  tpsCost = tps: consumptionW * USDperWs / tps; # 100W * 5e-8 USD/Ws

  tps32k = {  # benchmarked at 32k context
    "qwen3.5-sparse-quick" = { input_tps = 450; output_tps = 42; };
    "qwen3.5-sparse" = { input_tps = 180; output_tps = 18; };
    "qwen3.5-dense" = { input_tps = 85; output_tps = 9; };
    "qwen3.5-dense-quick" = { input_tps = 260; output_tps = 28; };
    "qwen3.5-dense-blitz" = { input_tps = 3000; output_tps = 133; };
    "gpt-oss:20b" = { input_tps = 450; output_tps = 41; };
    "gpt-oss:120b" = { input_tps = 280; output_tps = 29; };
  };

  mkModel = extra: ctx: name:
    let
      fullName = "hosted_vllm/${name}";
      t = tps32k."${name}" or null;
      costAttrs = if t != null then {
        input_cost_per_token = tpsCost t.input_tps;
        output_cost_per_token = tpsCost t.output_tps;
      } else {};
    in {
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
      } // costAttrs;
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
    "qwen3.5-sparse" = mkQwen;
    "qwen3.5-dense" = mkQwen;
    "qwen3.5-sparse-quick" = mkQwenQuick;
    "qwen3.5-dense-quick" = mkQwenQuick;
    "qwen3.5-dense-blitz" = mkQwenQuick;
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
    enable = lib.mkDefault false;
    package = null;
    settings = {
      model = "qwen3.5-sparse";
      editor-model = "qwen3.5-sparse-quick";
      weak-model = "qwen3.5-dense-blitz";
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

  home.packages = lib.mkIf config.programs.aider-chat.enable [
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
