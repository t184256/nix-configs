{ inputs, config, lib, pkgs, ... }:

let
  # The module's vanilla preStart installs config.json as root:0600, sidestep.
  settingsFile = pkgs.writeText "paseo-config.json"
    (builtins.toJSON config.services.paseo.settings);
in
{
  imports = [ inputs.paseo.nixosModules.paseo ];

  services.paseo = {
    enable = true;
    user = "monk";
    group = "users";  # monk's actual primary group, avoids group creation
    listenAddress = "192.168.99.53";  # nebula-only
    hostnames = [ "192.168.99.53" "plum" ];
    openFirewall = true;  # 6767
    relay.enable = false;

    settings = {
      # dictation STT via cocoa's whisper-server, avoids model downloading
      features.dictation = {
        enabled = true;
        stt = {
          provider = "openai";
          apiKey = "dummy";
          baseUrl = "http://192.168.99.7:11112/v1";
        };
      };
      agents = {
        providers = {
          claude.enabled = false;
          codex.enabled = false;
          copilot.enabled = false;
          opencode.enabled = false;
          jailed-pi = {
            extends = "pi";
            label = "jailed-pi";
            command = [ "/etc/profiles/per-user/monk/bin/jailed-pi" ];
          };
        };
        resumeOnStartup = true; # sessions survive daemon restarts / reboots
        idleRuntimeCleanup = true; # reap idle agent runtimes
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/monk/.pi/paseo-tmp 0700 monk users - -"
  ];

  systemd.services.paseo = {
    after = [ "nebula@unboiled.service" ];
    # replaces the module's root:0600 install; re-runs on every startup
    preStart = lib.mkForce ''
      install -m 0600 -o monk -g users ${settingsFile} \
        ${config.services.paseo.dataDir}/config.json
    '';
    serviceConfig = {
      Environment = [ "TMPDIR=/home/monk/.pi/paseo-tmp" ];  # jail sees ~/.pi
      LoadCredential = [ "llm.key:/mnt/secrets/llm" ];  # see user/jailed-pi.nix
      EnvironmentFile = "/mnt/secrets/paseo"; # `PASEO_{PASSWORD,SERVER_ID}=...`
      MemoryMax = "32G";  # OOM kill worst offenders
      AllowedCPUs = "2-11";  # keep 2 cores free. TODO: bump on CPU upgrades =)
    };
  };

  environment.persistence."/mnt/persist".users.monk.directories = [
    ".paseo/agents"
    ".paseo/projects"
  ];
}
