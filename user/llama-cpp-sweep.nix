{ pkgs, config, lib, ... }:

let
  port = 8765;
  backendPort = 8766;
  idleTime = "10min";
  llamaCpp = if config.system.noGraphics then pkgs.llama-cpp else pkgs.llama-cpp-vulkan;
  nixGLWrap = if config.system.os == "OtherLinux" && !config.system.noGraphics
    then "${pkgs.nixgl.nixVulkanIntel}/bin/nixVulkanIntel "
    else "";
  model = pkgs.fetchurl {
    url = "https://huggingface.co/sweepai/sweep-next-edit-0.5B/resolve/main/sweep-next-edit-0.5b.q8_0.gguf";
    hash = "sha256-LS9cqFZ2WghtTuPQ3E0wNY6dVi42SA4MdUJA6c9F7WQ=";
  };
in
{
  imports = [ ./config/no-graphics.nix ];

  systemd.user.sockets.llama-cpp-sweep = {
    Unit.Description = "Sweep llama-server socket";
    Socket.ListenStream = port;
    Install.WantedBy = [ "sockets.target" ];
  };

  systemd.user.services.llama-cpp-sweep = {
    Unit = {
      Description = "Sweep llama-server proxy";
      Requires = [ "llama-cpp-sweep-backend.service" ];
      After = [ "llama-cpp-sweep-backend.service" ];
    };
    Service = {
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=${idleTime} 127.0.0.1:${toString backendPort}";
      NonBlocking = true;
      Restart = "no";
    };
  };

  systemd.user.services.llama-cpp-sweep-backend = {
    Unit = {
      Description = "Sweep llama-server backend";
      BindTo = [ "llama-cpp-sweep.service" ];
    };
    Service = {
      ExecStart = "${nixGLWrap}${llamaCpp}/bin/llama-server --host 127.0.0.1 --port ${toString backendPort} --ctx-size 2048 --log-disable -ngl 999 -m ${model}";
      Restart = "no";
    };
  };
}
