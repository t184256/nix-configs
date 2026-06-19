{ lib, pkgs, ... }:

{
  # hand-rolled because the JWE is in the LUKS header instead of a file
  # TODO: watchdog
  boot.initrd.systemd.storePaths = with pkgs; [
    clevis
    "${jose}/bin/jose"
    "${curl}/bin/curl"
    "${cryptsetup}/bin/cryptsetup"
    "${gnused}/bin/sed"
    "${gnugrep}/bin/grep"
  ];
  boot.initrd.systemd.extraBin = with pkgs; {
    clevis = "${clevis}/bin/clevis";
    curl   = "${curl}/bin/curl";
  };
  boot.initrd.systemd.services.clevis-unlock-root = {
    wantedBy = [ "cryptsetup.target" ];
    before   = [ "systemd-cryptsetup@root.service" ];
    wants    = [ "network-online.target" ];
    after    = [ "systemd-udev-settle.service" "network-online.target" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = "PATH=${lib.makeBinPath (with pkgs; [
        clevis cryptsetup gnused gnugrep curl jose coreutils
      ])}";
    };
    script = ''
      clevis luks unlock \
        -d /dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_1TB_S7U4NU1YB17701K_1-part2 \
        -n root \
        || true
    '';
  };
}
