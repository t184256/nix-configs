# TODO: try jj-specific https://github.com/anglesideangle/jjinn
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
      thinkingTokenBudgetField = "thinking_budget_tokens";
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
          # interactive: plum's qwen3.8-27b; batch: grapefruit's
          ({ id = "interactive"; reasoning = true;
            input = [ "text" "image" ];
            contextWindow = 262144;
            cost = { input = 0.017; output = 0.59;
                     cacheRead = 0; cacheWrite = 0; }; }
            // qwen38Effort)
          ({ id = "batch"; reasoning = true;
            input = [ "text" "image" ];
            contextWindow = 262144;
            cost = { input = 0.017; output = 0.59;
                     cacheRead = 0; cacheWrite = 0; }; }
            // qwen38Effort)
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
    defaultModel = "interactive";
    tuiMode = "fullscreen";
    fullscreenScrollbar = "away";
    thinkingBudgets = {
      low = 1024;
      medium = 4096;
      high = 16384;  # xhigh is mapped to high
    };
    quietStartup = true;
    extensions = [
      "extensions/llama-cpp-stats.ts"
      "extensions/no-tail-pipe.ts"
    ];
    packages = [
      "npm:pi-web-access@0.10.7"
      #"npm:@ribbons-digital/pi-advisor"  # disabled for now
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
    #cp -r ${pkgs.pi-advisor}/lib/node_modules/* $out  # disabled for now
  '';

  # pi-advisor disabled for now
  #watchdogYml = pkgs.writeText "WATCHDOG.yml" (builtins.toJSON {
  #  version = 1;
  #  model = "litellm/qwen3.5-122b-a10b-think";
  #  effort = "high";
  #  defaultEnabled = true;
  #});
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

  # podman machine QEMU provider looks for helper binaries in
  # /usr/libexec/podman, not on $PATH
  podmanHelpers = pkgs.runCommand "podman-machine-helpers" { } ''
    mkdir $out
    ln -s ${pkgs.gvproxy}/bin/gvproxy $out/
    ln -s ${pkgs.virtiofsd}/bin/virtiofsd $out/
    ln -s ${pkgs.qemu_kvm}/bin/qemu-system-x86_64 $out/
    ln -s ${pkgs.qemu_kvm}/bin/qemu-img $out/
  '';

  # Wraps podman: auto-inits/starts the VM if it isn't running
  podmanWrapper = pkgs.writeShellScriptBin "podman" ''
    set -euo pipefail
    export PATH="${pkgs.openssh}/bin:$PATH" # is needed on $PATH
    REAL=${pkgs.podman}/bin/podman
    if [ "$#" -lt 2 ] || [ "$1" != "machine" ] || \
        ( [ "$2" != "stop" ] && [ "$2" != "rm" ]; ); then
        if ! "$REAL" machine list --format '{{.Running}}' 2>/dev/null \
            | grep -qx true; then
          if "$REAL" machine list --format '{{.Default}}' 2>/dev/null \
            | grep -qx true; then
            "$REAL" machine start  # defaults to podman-machine-default
          else
            "$REAL" machine init --now -m 4096 --disk-size 12 \
              podman-machine-default
          fi
      fi
    fi
    export CONTAINER_CONNECTION=podman-machine-default
    exec "$REAL" "$@"
  '';

  agentsMd = pkgs.writeText "AGENTS.md" ''
    ## Nix Environment

    You only have the most basic tools installed.
    `nix shell nixpkgs#python3 nixpkgs#file --command <command> <arguments>`
    if you need more. Command and arguments must not be quoted together.

    ## Podman (VM-backed)

    It is possible to use containers via `podman`, but it is a wrapper that
    auto-inits/starts a QEMU/KVM, user-mode networking VM on first use
    (state is lost for resumed sessions) and then runs containers inside VM.
    `podman run -it fedora /usr/bin/echo hello` should work.

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

  # https://alexdav.id/projects/jail-nix/combinators/
  # https://git.sr.ht/~alexdavid/jail.nix
  extraJailOpts = with comb; [
    (fwd-env "LLAMA_KEY")
    (fwd-env "PWD")
    (write-text (noescape "~/.config/nix/nix.conf") ''
      experimental-features = nix-command flakes
    '')
    (ro-bind "${pkgs.coreutils}/bin/env" "/usr/bin/env")
    (ro-bind (noescape "~/.agents") (noescape "~/.agents"))
    (ro-bind nixRegistry (noescape "~/.config/nix/registry.json"))
    (try-ro-bind "/etc/pki" "/etc/pki")  # Fedora hack
    # Runs on the host before the jail starts.
    (add-runtime ''
      mkdir -p ~/.pi ~/.agents
      if [ ! -d ~/.agents/skills ]; then
        git clone git@git.slop.unboiled.info:monk/skills ~/.agents/skills
      fi
    '')
    (unsafe-add-raw-args "--dev-bind-try /dev/kvm /dev/kvm")
    # podman machine: user-mode networking via gvproxy, no tun needed;
    # state lives on tmpfs ~ and is recreated each session
    (ro-bind podmanHelpers "/usr/libexec/podman")
  ]
  # deferred so these layer on top of ~/.pi from makeJailedPi
  ++ map (defer) [
    (ro-bind modelsJson (noescape "~/.pi/agent/models.json"))
    (ro-bind settingsJson (noescape "~/.pi/agent/settings.json"))
    (ro-bind webSearchJson (noescape "~/.pi/web-search.json"))
    (ro-bind keybindingsJson (noescape "~/.pi/agent/keybindings.json"))
    (ro-bind agentsMd (noescape "~/.pi/agent/AGENTS.md"))
    (ro-bind llamaCppStatsSrc
      (noescape "~/.pi/agent/extensions/llama-cpp-stats.ts"))
    (ro-bind noTailPipeSrc (noescape "~/.pi/agent/extensions/no-tail-pipe.ts"))
    (ro-bind piNpmNodeModules (noescape "~/.pi/agent/npm/node_modules"))
    # pi-advisor disabled for now
    #(ro-bind watchdogYml (noescape "~/.pi/agent/WATCHDOG.yml"))
  ];

  jailedPi = jailedAgentsLib.makeJailedPi {
    name = "jailed-pi";
    pkg = pkgs.pi-coding-agent;
    env = { PI_SKIP_VERSION_CHECK = "1"; };
    enableNix = true;
    extraPkgs = with pkgs; [
      pi-coding-agent
      gh xxd gnutar
      podmanWrapper
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
