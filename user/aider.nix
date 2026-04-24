{ pkgs, config, lib, ... }:

let
  ctx196k = 196608;
  ctx256k = 262144;

  consumptionW = 100; # Electricity-based cost model, assuming 100W consumption
  USDperWs = 5.0e-8; # 0.15 USD/KWh = 0.15 / (3600 * 1000) USD/Ws = ~5e-8 USD/Ws
  tpsCost = tps: consumptionW * USDperWs / tps; # 100W * 5e-8 USD/Ws

  tps32k = {  # benchmarked at 32k context
    "qwen3.6-35b-a3b" = { input_tps = 3000; output_tps = 100; };  # plum
    "qwen3.5-27b" = { input_tps = 1100; output_tps = 30; };  # plum
    "qwen3.5-122b-a10b" = { input_tps = 280; output_tps = 29; };  # grapefruit
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

  # sampling params injected by LiteLLM, don't override here
  mkQwenPlum = mkModel {} ctx196k;
  mkQwenGrapefruit = mkModel {} ctx256k;

  models = {
    "qwen3.6-35b-a3b-nothink" = mkQwenPlum;
    "qwen3.6-35b-a3b-think" = mkQwenPlum;
    "qwen3.5-27b-nothink" = mkQwenPlum;
    "qwen3.5-27b-think" = mkQwenPlum;
    "qwen3.5-122b-a10b-nothink" = mkQwenGrapefruit;
    "qwen3.5-122b-a10b-think" = mkQwenGrapefruit;
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
      model = "qwen3.5-27b-think";
      editor-model = "qwen3.5-27b-nothink";
      weak-model = "qwen3.5-27b-nothink";
      #model = "qwen3.5-122b-a10b-think";
      #editor-model = "qwen3.6-35b-a3b-nothink";
      #weak-model = "qwen3.6-35b-a3b-nothink";
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
