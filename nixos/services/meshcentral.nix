{ ... }:

{
  services.meshcentral = {
    enable = true;
    settings = {
      domains."" = {
        certUrl = "https://meshcentral.unboiled.info";
      };
      settings = {
        Cert = "meshcentral.unboiled.info";
        Port = 1025;
        AliasPort = 443;
        TlsOffload = "127.0.0.1";
        WANonly = true;
      };
    };
  };
  networking.firewall.allowedTCPPorts = [ 4433 ];  # CIRA
  services.nginx = {
    enable = true;
    virtualHosts."meshcentral.unboiled.info" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:1025";
        proxyWebsockets = true;
      };
    };
  };
  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/var/lib/private/meshcentral";
      user = "meshcentral"; group = "meshcentral";
    }
  ];
}
