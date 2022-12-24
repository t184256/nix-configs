{ pkgs, ... }:

let
  config = ''
    origin_web_ui_allowed = lan
    adapter_name = /dev/dri/renderD128
    hevc_mode = 1
  '';
  configFile = pkgs.writeTextFile { name = "sunshine.conf"; text = config; };
in
{
  systemd.services.sunshine = {
    description = "Sunshine Gamestream host";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      Environment = "HOME=/var/lib/sunshine";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/sunshine/.config";
      ExecStart = "${pkgs.sunshine}/bin/sunshine ${configFile}";
    };
  };

  networking.firewall.allowedTCPPorts = [ 47984 47989 47990 48010 ];
  networking.firewall.allowedUDPPorts = [ 47998 47999 48000 48002 ];

  environment.persistence."/mnt/persist".directories = [ "/var/lib/sunshine" ];
}
