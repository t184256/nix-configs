{ pkgs, ... }:

{
  systemd.services.whisper-cpp = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.ffmpeg ];
    serviceConfig = {
      DynamicUser = true;
      User = "whisper-cpp";
      ExecStart = [
        ("${pkgs.whisper-cpp-vulkan}/bin/whisper-server" +
         " --host 192.168.99.52 --port 11112 --language auto --flash-attn" +
         " --inference-path /v1/audio/transcriptions --convert" +
         " --model /var/lib/whisper/model.bin"
        )
      ];
      CapabilityBoundingSet = "";
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      PrivateTmp = true;
      PrivateUsers = true;
      ProtectControlGroups = true;
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
  environment.persistence."/mnt/persist".directories = [
    { directory = "/var/lib/whisper"; }
  ];
}
