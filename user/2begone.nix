{ config, pkgs, ... }:

{
  home.packages = [ (pkgs.writeShellScriptBin "2begone" ''
    set -ueo pipefail
    sudo find / -xdev -type f \
      | sort \
      | grep -vE '^/etc/\.(pwd.lock|updated|clean)$' \
      | grep -vE '^/etc/(subuid|subgid|shadow|passwd|group|sudoers)$' \
      | grep -vE '^/etc/machine-id$' \
      | grep -vE '^/etc/resolv.conf$' \
      | grep -vE '^/etc/NIXOS$' \
      | grep -vE '^/etc/ssh/ssh_host_(ed25519|rsa)_key(\.pub|)$' \
      | grep -vE '^/home/monk/\.bash_history$' \
      | grep -vE '^/home/monk/.cache/' \
      | grep -vE '^/root/.cache/' \
      | grep -vE '^/var/\.update$' \
      | grep -vE '^/var/db/dhcpcd/' \
      | grep -vE '^/var/lib/nixos/.*id-map$' \
      | grep -vE '^/var/lib/nixos/declarative-' \
      | grep -vE '^/var/lib/nsd/' \
      | grep -vE '^/var/lib/systemd/' \
      | grep -vE '^/var/log'
  '') ];
}
