{ pkgs, ... }:

let
  tangToml = builtins.fromTOML (builtins.readFile ../../misc/pubkeys/tang.toml);
  tangThp = tangToml.quince;
  tangUrl = "http://192.168.98.1:1449";
  luksDevice =
    "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_1TB_S7U4NU1YB17701K_1-part2";
in

{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "clevis-highlevel" ''
      set -euo pipefail
      case "''${1:-}" in
        check)
          echo "Decrypting clevis JWE via tang at ${tangUrl}..."
          ${pkgs.clevis}/bin/clevis decrypt < /mnt/secrets/clevis \
            | cryptsetup open --test-passphrase ${luksDevice} --key-file=-
          echo "OK"
          ;;
        lock)
          echo "Re-encrypting LUKS key to tang at ${tangUrl}..."
          ${pkgs.clevis}/bin/clevis encrypt tang \
            '{"url":"${tangUrl}","thp":"${tangThp}"}' \
            < /mnt/secrets/root.luks > /mnt/secrets/clevis
          echo "OK"
          ;;
        *)
          echo "Usage: clevis-highlevel {check|lock}" >&2
          exit 1
          ;;
      esac
    '')
  ];
}
