{ config, pkgs, ... }:

{
  # without lockdown:
  # sudo prosodyctl register monk meet.unboiled.info TEMPORARY_PASSWORD
  # login through an XMPP client and change password
  #networking.firewall.allowedTCPPorts = [ 5222 ];
  nixpkgs.config.permittedInsecurePackages = [ "jitsi-meet-1.0.8043" ];
  services.jitsi-meet = {
    enable = true;
    hostName = "meet.unboiled.info";
    secureDomain.enable = true;
    prosody.lockdown = true;
    config = {
      prejoinPageEnable = true;
    };
  };
  services.jitsi-videobridge.openFirewall = true;
  #services.prosody = {
  #  ssl.cert = "/var/lib/acme/unboiled.info-prosody/fullchain.pem";
  #  ssl.key = "/var/lib/acme/unboiled.info-prosody/key.pem";
  #};
  environment.persistence."/mnt/persist".directories = [
    { directory = "/var/lib/prosody"; user = "prosody"; group = "prosody"; }
    { directory = "/var/lib/jitsi-meet"; user = "root"; group = "jitsi-meet"; }
  ];
}
