{ pkgs, ... }:

let
  luks = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_1TB_S7U4NU1YB17701K_1-part2";
  luksKey = "/mnt/secrets/root.luks";
  luksSlot = "2";
  tangUrl = "http://192.168.98.4:1449";
  # TODO: use https on a public server
  # TODO: SSS / secure boot
  clevis = "${pkgs.clevis}/bin/clevis";
  cryptsetup = "${pkgs.cryptsetup}/bin/cryptsetup";
in

{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "safe-reboot" ''
      set -eEuo pipefail
      if [ "$(id -u)" != "0" ]; then
        echo "must be run as root" >&2; exit 1
      fi
      [ $# -gt 0 ] && dry=1 || dry=0

      if ${clevis} luks list -d ${luks} 2>/dev/null \
          | grep -q "^${luksSlot}:"; then
        echo "Removing existing clevis slot ${luksSlot}..."
        ${cryptsetup} luksKillSlot \
          --batch-mode --key-file ${luksKey} ${luks} ${luksSlot}
      fi
      echo "Binding LUKS slot ${luksSlot} to current tang key..."
      ${clevis} luks bind -y -d ${luks} -k ${luksKey} -s ${luksSlot} \
        tang '{"url":"${tangUrl}"}'

      if [ "$dry" = "1" ]; then
        echo "Dry run, skipping reboot."
      else
        echo "Rebooting..."
        systemctl reboot
      fi
    '')
  ];
}
