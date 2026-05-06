{ pkgs, ... }:

let
  server = "${pkgs.ik-llama-cpp}/bin/llama-server";
  # nothink/instruct defaults; router overrides per-request for think models
  base = server
    + " --host 127.0.0.1 --port " + "$" + "{PORT}"
    + " --jinja -ngl 999"
    + " --chat-template-kwargs {\\\"enable_thinking\\\":false}"
    + " --temp 0.7 --top-p 0.8 --top-k 20 --min-p 0.0 --presence-penalty 1.5"
    + " --parallel 1"
    + " -sm graph";
    #--run-time-repack

  configFile = (pkgs.formats.yaml { }).generate "llama-swap.yaml" {
    healthCheckTimeout = 120;
    models = {
      "qwen3.6-35b-a3b" = {
        cmd = base
          + " --model ${pkgs.qwen36-35b-a3b-q4km}"
          + " --cache-type-k q8_0 --cache-type-v q8_0"
          + " --cache-ram 4096"
          + " --ctx-size 196608"
          + " --ctx-checkpoints-interval 6144"; # 32*6144=196k coverage
      };
      "qwen3.6-27b" = {
        cmd = base
          + " --model ${pkgs.qwen36-27b-q4km}"
          + " --cache-type-k q8_0 --cache-type-v q8_0"
          + " --cache-ram 4096"
          + " --ctx-size 196608"
          + " --ctx-checkpoints-interval 6144"; # 32*6144=196k coverage
      };
    };
  };
in

{
  systemd.services.llama-swap = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "ik-llama-cpp";
      Group = "ik-llama-cpp";
      ExecStart =
        "${pkgs.llama-swap}/bin/llama-swap"
        + " --listen=192.168.99.53:11111"
        + " --config=${configFile}";
      Environment = [
        "XDG_CACHE_HOME=/var/lib/ik-llama/.cache"
        "LD_LIBRARY_PATH=/run/opengl-driver/lib"
      ];
      PrivateDevices = false;
      PrivateTmp = true;
      ProtectHome = true;
    };
  };

  users.groups.ik-llama-cpp = { };
  users.users.ik-llama-cpp = {
    isSystemUser = true;
    group = "ik-llama-cpp";
    extraGroups = [ "video" "render" ];
  };

  networking.firewall.allowedTCPPorts = [ 11111 ];

  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/var/lib/ik-llama";
      user = "ik-llama-cpp";
      group = "ik-llama-cpp";
    }
  ];
}
