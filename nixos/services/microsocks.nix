_:

{
  services.microsocks = {
    enable = true;
    ip = "::";
    #outgoingBindIp = "::";
    port = 2780;
    authUsername = "y";
    authPasswordFile = "/mnt/persist/secrets/microsocks";
    #authPasswordFile = "/run/credentials/microsocks.service/pass";
  };

  #systemd.services.microsocks.serviceConfig.LoadCredential = [
  #  "pass:/mnt/persist/secrets/microsocks"
  #];

  networking.firewall.allowedTCPPorts = [ 2780 ];
}
