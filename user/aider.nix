{ pkgs, config, ... }:

let
  modelSettings = builtins.toJSON [
    {
      name = "hosted_vllm/gpt-oss:120b";
      edit_format = "editor-diff";
      use_repo_map = true;
      streaming = true;
      accepts_settings = [ "reasoning_effort" ];
    }
  ];
  modelSettingsFile = pkgs.writeText "aider.model.settings.json" modelSettings;
  aiderPkg = if config.system.noGraphics
    then pkgs.aider-chat
    else pkgs.aider-chat-with-playwright;
in
{
  imports = [ ./config/no-graphics.nix ];

  programs.aider-chat = {
    enable = true;
    package = null;
    settings = {
      model = "hosted_vllm/gpt-oss:120b";
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
