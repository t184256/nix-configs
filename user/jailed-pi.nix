# TODO: try jj-specific https://github.com/anglesideangle/jjinn

{ pkgs, lib, inputs, config, ... }:

let
  jailedAgentsLib = inputs.jailed-agents.lib.${pkgs.system};
  comb = jailedAgentsLib.internals.jail.combinators;

  modelsRaw = builtins.toJSON {
    providers = {
      litellm = {
        baseUrl = "https://llm.slop.unboiled.info/v1";
        api = "openai-completions";
        apiKey = "$LLAMA_KEY";
        compat = {
          thinkingFormat = "qwen-chat-template";
          supportsDeveloperRole = false;
          maxTokensField = "max_tokens";
        };
        models = [
          { id = "qwen3.5-35b-a3b-think"; reasoning = true;
            contextWindow = 262144;
            cost = { input = 0.011; output = 0.12;
                     cacheRead = 0; cacheWrite = 0; }; }
          { id = "qwen3.6-35b-a3b-nothink";
            contextWindow = 262144;
            cost = { input = 0.011; output = 0.12;
                     cacheRead = 0; cacheWrite = 0; }; }
          { id = "qwen3.6-35b-a3b-think"; reasoning = true;
            supportsDeveloperRole = true;
            contextWindow = 262144;
            cost = { input = 0.011; output = 0.12;
                     cacheRead = 0; cacheWrite = 0; }; }
          { id = "qwen3.6-35b-a3b-nothink";
            supportsDeveloperRole = true;
            contextWindow = 262144;
            cost = { input = 0.011; output = 0.12;
                     cacheRead = 0; cacheWrite = 0; }; }
          { id = "qwen3.5-122b-a10b-think"; reasoning = true;
            contextWindow = 262144;
            cost = { input = 0.028; output = 0.28;
                     cacheRead = 0; cacheWrite = 0; }; }
          { id = "qwen3.5-122b-a10b-nothink";
            contextWindow = 262144;
            cost = { input = 0.028; output = 0.28;
                     cacheRead = 0; cacheWrite = 0; }; }
          { id = "qwen3.6-27b-think"; reasoning = true;
            contextWindow = 262144;
            cost = { input = 0.017; output = 0.59;
                     cacheRead = 0; cacheWrite = 0; }; }
          { id = "qwen3.6-27b-nothink";
            contextWindow = 262144;
            cost = { input = 0.017; output = 0.59;
                     cacheRead = 0; cacheWrite = 0; }; }
        ];
      };
      plum = {
        baseUrl = "http://192.168.99.53:11111/v1";
        api = "openai-completions";
        apiKey = "dummy";
        compat = {
          thinkingFormat = "qwen-chat-template";
          supportsDeveloperRole = false;
          maxTokensField = "max_tokens";
        };
        models = [
          { id = "qwen3.6-27b-think"; reasoning = true;
            contextWindow = 262144;
            cost = { input = 0; output = 0;
                     cacheRead = 0; cacheWrite = 0; }; }
          { id = "qwen3.6-27b-nothink";
            contextWindow = 262144;
            cost = { input = 0; output = 0;
                     cacheRead = 0; cacheWrite = 0; }; }
        ];
      };
    };
  };

  settingsRaw = builtins.toJSON {
    defaultProvider = "litellm";
    defaultModel = "qwen3.6-27b-think";
    quietStartup = true;
  };

  # makeJailedAgent puts configPaths last, shadowing any ro-bind in
  # baseJailOptions. Use add-runtime to inject the ro-binds AFTER
  # configPaths by appending to $RUNTIME_ARGS.
  modelsJson = pkgs.writeText "models.json" modelsRaw;
  settingsJson = pkgs.writeText "settings.json" settingsRaw;

  extraJailOpts = [
    (comb.fwd-env "LLAMA_KEY")
    (comb.fwd-env "PWD")
    (comb.add-runtime ''
      RUNTIME_ARGS+=(--ro-bind ${modelsJson} ~/.pi/agent/models.json)
      RUNTIME_ARGS+=(--ro-bind ${settingsJson} ~/.pi/agent/settings.json)
      RUNTIME_ARGS+=(--ro-bind-try /etc/pki /etc/pki)  # Fedora hack
    '')
  ];

  jailedPi = jailedAgentsLib.makeJailedPi {
    name = "jailed-pi";
    pkg = pkgs.pi-coding-agent;
    env = { PI_SKIP_VERSION_CHECK = "1"; };
    extraPkgs = [ pkgs.nix ];
    baseJailOptions = jailedAgentsLib.commonJailOptions ++ extraJailOpts;
  };

  jailed-pi = pkgs.writeShellScriptBin "jailed-pi" ''
    set -Eeuo pipefail; shopt -s inherit_errexit
    export LLAMA_KEY=$(cat /mnt/secrets/llm)
    exec ${jailedPi}/bin/jailed-pi "$@"
  '';

in
{
  imports = [ ./config/roles.nix ];
  nixpkgs.overlays = lib.mkIf config.roles.slop [ (import ../overlays/pi) ];
  home.packages = lib.mkIf config.roles.slop [ jailed-pi ];
}
