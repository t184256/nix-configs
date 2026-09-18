{ pkgs, lib, ... }:

# . <(curl https://s.unboiled.info/ssh)

let
  #selfUrl = "https://raw.githubusercontent.com/t184256/nix-configs/staging/";
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
    t14 = builtins.readFile ../../misc/inst/t14g5;
    intermezzo = builtins.readFile ../../misc/inst/intermezzo;
    csb = ''
      FORGE=$(grep -m1 -oP '(?<=git clone https://)[^/]+redhat.com' \
                   /usr/lib/py*/s*/rh_git*/METADATA)
      wget -O /tmp/.managed.entry-point \
              "$FORGE/asosedki/managed/-/raw/staging/csb/entry-point"
      [ "$(sha256sum /tmp/.managed.entry-point | cut -f1 '-d ')" = \
        1427a53217803db45eb9e367345fcd1eff13830551f8c5ed3cac3eca17fd2791 ]
      chmod +x /tmp/.managed.entry-point
      exec /tmp/.managed.entry-point "$@"
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
