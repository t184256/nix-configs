{ pkgs, lib, ... }:

# curl https://s.unboiled.info/ssh | bash -s

let
  strict = "set -Eeuo pipefail; shopt -s inherit_errexit\n";
  mkScript = name: text: pkgs.writeText ("short-script-" + name) (strict + text);
  scripts = {
    ssh = ''
      mkdir -p ~/.ssh
      curl https://github.com/t184256.keys >> ~/.ssh/authorized_keys
      sudo systemctl start sshd
      id -un
      ip a | grep inet | grep -vwF 127.0.0.1/8 | grep -vwF 'inet6 ::1/128' ||:
    '';
  };
  short-scripts-dir = pkgs.linkFarm "short-scripts" (lib.mapAttrsToList
    (name: text: { inherit name; path = mkScript name text; }) scripts
  );
in
{
  services.nginx = {
    enable = true;
    virtualHosts."s.unboiled.info" = {
      enableACME = true;
      forceSSL = true;
      root = short-scripts-dir;
    };
  };
  security.acme.certs."s.unboiled.info".email = "monk@unboiled.info";
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
