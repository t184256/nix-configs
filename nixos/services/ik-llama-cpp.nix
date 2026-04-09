{ pkgs, ... }:

let
  server = "${pkgs.ik-llama-cpp}/bin/llama-server";
  base = server
    + " --host 127.0.0.1 --port " + "$" + "{PORT}"
    + " --jinja -ngl 999";  #--run-time-repack";

  configFile = (pkgs.formats.yaml { }).generate "llama-swap.yaml" {
    healthCheckTimeout = 120;
    models = {
      "qwen35-35b-a3b" = {
        cmd = base
          + " --model ${pkgs.qwen35-35b-a3b-iq4xs}"
          + " --cache-type-k q8_0 --cache-type-v q8_0"
          + " --cache-ram 4096"
          + " --ctx-size 262144";
      };
      "qwen35-27b" = {
        cmd = base
          + " --model ${pkgs.qwen35-27b-iq4xs}"
          + " --cache-type-k q8_0 --cache-type-v q8_0"
          + " --cache-ram 4096"
          + " --ctx-size 196608";
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
