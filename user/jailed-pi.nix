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
        models = map (m: m // { samplingParams = { return_progress = true; }; }) [
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
          { id = "qwen3.8-27b-think"; reasoning = true;
            input = [ "text" "image" ];
            contextWindow = 262144;
            cost = { input = 0.017; output = 0.59;
                     cacheRead = 0; cacheWrite = 0; }; }
          { id = "qwen3.8-27b-nothink";
            input = [ "text" "image" ];
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
          { id = "qwen3.8-27b-think"; reasoning = true;
            input = [ "text" "image" ];
            contextWindow = 262144;
            cost = { input = 0; output = 0;
                     cacheRead = 0; cacheWrite = 0; };
            samplingParams = { return_progress = true; }; }
          { id = "qwen3.8-27b-nothink";
            input = [ "text" "image" ];
            contextWindow = 262144;
            cost = { input = 0; output = 0;
                     cacheRead = 0; cacheWrite = 0; };
            samplingParams = { return_progress = true; }; }
        ];
      };
    };
  };

  settingsRaw = builtins.toJSON {
    defaultProvider = "litellm";
    defaultModel = "qwen3.8-27b-think";
    quietStartup = true;
    extensions = [ "extensions/llama-cpp-stats.ts" ];
    packages = ["npm:pi-web-access@0.10.7"];
  };

  # pi-llama-cpp-stats: single .ts file, zero deps (from overlay)
  llamaCppStatsSrc = pkgs.pi-llama-cpp-stats;

  # npm-based extensions, copied into a single node_modules tree (incl. deps)
  piNpmNodeModules = pkgs.runCommand "pi-npm-node-modules" {} ''
    cp -r ${pkgs.pi-web-access}/lib/node_modules $out
  '';

  # makeJailedAgent puts configPaths last, shadowing any ro-bind in
  # baseJailOptions. Use add-runtime to inject the ro-binds AFTER
  # configPaths by appending to $RUNTIME_ARGS.
  modelsJson = pkgs.writeText "models.json" modelsRaw;
  settingsJson = pkgs.writeText "settings.json" settingsRaw;
  webSearchJson = pkgs.writeText "web-search.json"
    (builtins.toJSON { workflow = "none"; });
  nixRegistry = pkgs.writeText "registry.json" (builtins.toJSON {
    version = 2;
    flakes = [
      {
        from = { id = "nixpkgs"; type = "indirect"; };
        to = { __final = true; lastModified = 0;
               path = inputs.nixpkgs.outPath; type = "path"; };
      }
    ];
  });

  agentsMd = pkgs.writeText "AGENTS.md" ''
    ## Nix Environment

    You only have the most basic tools installed.
    `nix shell nixpkgs#<package1> nixpkgs#package2 --command <command>
    if you need more."
  '';

  extraJailOpts = [
    (comb.fwd-env "LLAMA_KEY")
    (comb.fwd-env "PWD")
    (comb.write-text (comb.noescape "~/.config/nix/nix.conf") ''
      experimental-features = nix-command flakes
    '')
    (comb.add-runtime ''
      RUNTIME_ARGS+=(--ro-bind ${modelsJson} ~/.pi/agent/models.json)
      RUNTIME_ARGS+=(--ro-bind ${settingsJson} ~/.pi/agent/settings.json)
      RUNTIME_ARGS+=(--ro-bind ${webSearchJson} ~/.pi/web-search.json)
      RUNTIME_ARGS+=(--ro-bind ${agentsMd} ~/.pi/agent/AGENTS.md)
      RUNTIME_ARGS+=(--ro-bind ${nixRegistry} ~/.config/nix/registry.json)
      RUNTIME_ARGS+=(--ro-bind-try /etc/pki /etc/pki)  # Fedora hack
      RUNTIME_ARGS+=(--ro-bind ${llamaCppStatsSrc}
                               ~/.pi/agent/extensions/llama-cpp-stats.ts)
      RUNTIME_ARGS+=(--ro-bind ${piNpmNodeModules} ~/.pi/agent/npm/node_modules)
    '')
  ];

  jailedPi = jailedAgentsLib.makeJailedPi {
    name = "jailed-pi";
    pkg = pkgs.pi-coding-agent;
    env = { PI_SKIP_VERSION_CHECK = "1"; };
    enableNix = true;
    extraPkgs = with pkgs; [
      gh xxd
    ];
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
  nixpkgs.overlays = lib.mkIf config.roles.slop [
    (import ../overlays/pi)
    (import ../overlays/pi-extensions.nix)
  ];
  home.packages = lib.mkIf config.roles.slop [ jailed-pi ];
}
