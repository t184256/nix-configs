# TODO: try jj-specific https://github.com/anglesideangle/jjinn
# TODO: give it access to KVM
# TODO: give it access to podman through something like kata-containers
# TODO: let it run fingertip
# TODO: let it run lightweight nixos VMs built from this configuration

{ pkgs, lib, inputs, config, ... }:

let
  jailedAgentsLib = inputs.jailed-agents.lib.${pkgs.system};
  comb = jailedAgentsLib.internals.jail.combinators;

  qwen38Effort = {
    thinkingLevelMap = { # only low/medium/xhigh actually work, map to l/m/h
      minimal = null;
      low = "low";
      medium = "medium";
      high = "xhigh";
      xhigh = null;
      max = null;
    };
    compat = {
      thinkingFormat = "chat-template";
      chatTemplateKwargs = {
        enable_thinking = { "$var" = "thinking.enabled"; };
        preserve_thinking = true;
        reasoning_effort = { "$var" = "thinking.effort"; omitWhenOff = true; };
      };
    };
  };

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
          ({ id = "qwen3.8-27b-think"; reasoning = true;
            input = [ "text" "image" ];
            contextWindow = 262144;
            cost = { input = 0.017; output = 0.59;
                     cacheRead = 0; cacheWrite = 0; }; }
            // qwen38Effort)
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
          ({ id = "qwen3.8-27b-think"; reasoning = true;
            input = [ "text" "image" ];
            contextWindow = 262144;
            cost = { input = 0; output = 0;
                     cacheRead = 0; cacheWrite = 0; };
            samplingParams = { return_progress = true; }; }
            // qwen38Effort)
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
    tuiMode = "fullscreen";
    fullscreenScrollbar = "away";
    quietStartup = true;
    extensions = [
      "extensions/llama-cpp-stats.ts"
      "extensions/no-tail-pipe.ts"
    ];
    packages = [
      "npm:pi-web-access@0.10.7"
      "npm:@ribbons-digital/pi-advisor"
    ];
  };

  # pi-llama-cpp-stats: single .ts file, zero deps (from overlay)
  llamaCppStatsSrc = pkgs.pi-llama-cpp-stats;

  # no-tail-pipe: single .ts file, zero deps (from overlay)
  noTailPipeSrc = pkgs.no-tail-pipe;

  # npm-based extensions, copied into a single node_modules tree (incl. deps)
  piNpmNodeModules = pkgs.runCommand "pi-npm-node-modules" {} ''
    mkdir $out
    cp -r ${pkgs.pi-web-access}/lib/node_modules/* $out
    cp -r ${pkgs.pi-advisor}/lib/node_modules/* $out
  '';

  watchdogYml = pkgs.writeText "WATCHDOG.yml" (builtins.toJSON {
    version = 1;
    model = "litellm/qwen3.5-122b-a10b-think";
    effort = "high";
    defaultEnabled = true;
  });
  modelsJson = pkgs.writeText "models.json" modelsRaw;
  settingsJson = pkgs.writeText "settings.json" settingsRaw;
  webSearchJson = pkgs.writeText "web-search.json"
    (builtins.toJSON { workflow = "none"; });
  keybindingsJson = pkgs.writeText "keybindings.json" (builtins.toJSON {
    "tui.altScreen.top" = [ ];  # restore 'Home' jumping within the prompt
    "tui.altScreen.bottom" = [ ];  # restore 'End' jumping within the prompt
    "tui.altScreen.search" = "ctrl+s";
    "tui.altScreen.searchNext" = [ "down" "enter" "ctrl+g" ];  # down for next
    "tui.altScreen.searchPrevious" = [ "up" "ctrl+shift+g" ];  # up for previous
  });
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
    `nix shell nixpkgs#python3 nixpkgs#file --command <command> <arguments>`
    if you need more. Command and arguments must not be quoted together.

    ## Source code exploration

    If you need to inspect sources of other software,
    there's nothing wrong with cloning them to /tmp/ for ease of inspection.
    Just mind that they might disappear on session saving/resumption.

    ## Scope discipline

    The user's requests are the boundaries of what you're allowed to do.
    Purely investigative actions are always OK,
    as are out-of-tree clones/builds to /tmp;
    lasting or externally visible changes
    to the workspace or external resources, like manipulating other systems,
    modifying the versioned files, committing or building projects
    are only allowed when there's an explicit request authorizing that.
    Every destructive action must trace to the request itself,
    be an unavoidable substep of it,
    or be performed with no lasting side-effects.
    Your intermediate goals don't count towards extending the scope.

    When the user requests a specific non-investigative action
    or a status report, perform/reply right away.
    If you doubt your reply and it warrants a deeper investigation,
    note your concerns and let the user decide
    whether to proceed with that or not.
  '';

  extraJailOpts = [
    (comb.fwd-env "LLAMA_KEY")
    (comb.fwd-env "PWD")
    (comb.write-text (comb.noescape "~/.config/nix/nix.conf") ''
      experimental-features = nix-command flakes
    '')
    (comb.ro-bind "${pkgs.coreutils}/bin/env" "/usr/bin/env")
    (comb.add-runtime ''
      mkdir -p ~/.pi ~/.agents
      if [ ! -d ~/.agents/skills ]; then
        git clone git@git.slop.unboiled.info:monk/skills ~/.agents/
      fi
      RUNTIME_ARGS+=(--ro-bind ~/.agents ~/.agents)
      RUNTIME_ARGS+=(--ro-bind ${modelsJson} ~/.pi/agent/models.json)
      RUNTIME_ARGS+=(--ro-bind ${settingsJson} ~/.pi/agent/settings.json)
      RUNTIME_ARGS+=(--ro-bind ${webSearchJson} ~/.pi/web-search.json)
      RUNTIME_ARGS+=(--ro-bind ${keybindingsJson} ~/.pi/agent/keybindings.json)
      RUNTIME_ARGS+=(--ro-bind ${agentsMd} ~/.pi/agent/AGENTS.md)
      RUNTIME_ARGS+=(--ro-bind ${nixRegistry} ~/.config/nix/registry.json)
      RUNTIME_ARGS+=(--ro-bind-try /etc/pki /etc/pki)  # Fedora hack
      RUNTIME_ARGS+=(--ro-bind ${llamaCppStatsSrc}
                               ~/.pi/agent/extensions/llama-cpp-stats.ts)
      RUNTIME_ARGS+=(--ro-bind ${noTailPipeSrc}
                               ~/.pi/agent/extensions/no-tail-pipe.ts)
      RUNTIME_ARGS+=(--ro-bind ${piNpmNodeModules} ~/.pi/agent/npm/node_modules)
      RUNTIME_ARGS+=(--ro-bind ${watchdogYml} ~/.pi/agent/WATCHDOG.yml)
    '')
  ];

  jailedPi = jailedAgentsLib.makeJailedPi {
    name = "jailed-pi";
    pkg = pkgs.pi-coding-agent;
    env = { PI_SKIP_VERSION_CHECK = "1"; };
    enableNix = true;
    extraPkgs = with pkgs; [
      pi-coding-agent
      gh xxd gnutar
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
  nixpkgs.overlays = lib.mkIf config.roles.slop
    ([ (import ../overlays/pi) ]
     ++ ((import ../.autoimport).asList ../overlays/pi/extensions));
  home.packages = lib.mkIf config.roles.slop [ jailed-pi ];
}
