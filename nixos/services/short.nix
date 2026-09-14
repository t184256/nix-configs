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
    csb-r = ''
      mkdir -p /tmp/csb; cd /tmp/csb
      sudo dnf -y copr enable copr.devel.redhat.com/asosedki/multicsb
      sudo dnf -y install --refresh multicsb
      ls *.iso || multicsb download
      [ -f csb.pristine.img ] || \
        multicsb install $(ls -1 csb-fedora-*.iso | tail -n1) csb.pristine.img
      [ -f csb.1st.img ] || \
        multicsb first-boot --insecure-keep-keyfile --hardware-values \
                 --postconfig /usr/libexec/multicsb/example-csb-postconfig \
                 csb.pristine.img csb.1st.img
      sudo multicsb $(date +%Y-%m-%d-%H-%M-%S) prime-pivot csb.1st.img
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
