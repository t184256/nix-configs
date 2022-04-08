{ ... }:

{
  services.nginx = {
    enable = true;
    # decide what to do with these
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;
    appendHttpConfig = ''
      charset utf-8;
      autoindex_exact_size off;
    '';
    virtualHosts."nix-on-droid.unboiled.info" = {
      enableACME = true;
      forceSSL = true;
      root = "/srv/nix-on-droid";
      locations."/".extraConfig = ''
        autoindex on;
        location ~* \.apk$ {
          add_header Content-Type application/vnd.android.package-archive;
          add_header Content-Disposition "attachment";
        }
      '';
    };
  };
  security.acme.certs."nix-on-droid.unboiled.info".email = "monk@unboiled.info";
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
