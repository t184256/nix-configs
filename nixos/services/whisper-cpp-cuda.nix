{ inputs, pkgs, ... }:

let
  pkgsCuda = import inputs.nixpkgs {
    system = pkgs.system;
    config = { cudaSupport = true; rocmSupport = false; allowUnfree = true; };
    overlays = [ (import ../../overlays/models.nix) ];
  };

  whisperCpp = pkgsCuda.whisper-cpp.overrideAttrs (old: {
    # RTX 3090 = Ampere sm_86; Ryzen 7600 = Zen 3 (znver3)
    cmakeFlags = (old.cmakeFlags or []) ++ [
      "-DGGML_CPU_ALL_VARIANTS=OFF"
      "-DCMAKE_CUDA_ARCHITECTURES=86"
    ];
    CFLAGS = old.CFLAGS or "" + " -march=znver3";
    CXXFLAGS = old.CXXFLAGS or "" + " -march=znver3";
  });
  cudatoolkit = pkgsCuda.cudaPackages.cudatoolkit;

  #model = pkgsCuda.whisper-distil-large-v35;
  #model = pkgsCuda.whisper-large-turbo-q8_0;
  model = pkgsCuda.whisper-large-q5_0;
in

{
  systemd.services.whisper-cpp = {
    description = "whisper-cpp server (CUDA)";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ ffmpeg ];
    serviceConfig = {
      User = "whisper-cpp";
      Group = "whisper-cpp";
      Restart = "on-failure";
      RestartSec = 2;
      Environment = [
        "LD_LIBRARY_PATH=/run/opengl-driver/lib:${cudatoolkit}/lib:${cudatoolkit}/lib/stubs"
        "CUDA_HOME=${cudatoolkit}"
        "CUDA_VISIBLE_DEVICES=1"
      ];
      ExecStart =
        "${whisperCpp}/bin/whisper-server" +
        " --host 192.168.99.53 --port 11112 --language auto --flash-attn" +
        " --inference-path /v1/audio/transcriptions --convert" +
        " --best-of 4 --beam-size 4" +
        " --model ${model}";
      CapabilityBoundingSet = "";
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      PrivateDevices = false;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      RestrictAddressFamilies = [ ];  # full offline
      RestrictNamespaces = true;
      RestrictRealtime = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [ "@system-service" "~@privileged" ];
      UMask = "0077";
      WorkingDirectory = "/tmp/";
    };
  };

  networking.firewall.allowedTCPPorts = [ 11112 ];

  users.groups.whisper-cpp = { };
  users.users.whisper-cpp = {
    isSystemUser = true;
    group = "whisper-cpp";
    extraGroups = [ "video" "render" ];
  };
}
