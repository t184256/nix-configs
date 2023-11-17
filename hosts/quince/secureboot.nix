{ pkgs, lib, config, inputs, ... }:

{
  # debugging
  boot.initrd.systemd.extraConfig = ''
    LogLevel=debug
    StatusUnitFormat=combined
    DefaultTimeoutStartSec=10
    DefaultTimeoutStopSec=10
  '';

  boot.initrd.kernelModules = [ "efi_pstore" "efivarfs" "tpm_crb" "tpm_tis" ];
  environment.systemPackages = with pkgs; [ sbctl ];

  boot.initrd.systemd = {
    enable = true;
    additionalUpstreamUnits = [
      "systemd-pcrphase-initrd.service"
      "systemd-pcrphase.service"
    ];
    services.systemd-pcrphase-initrd = {
      wantedBy = [ "initrd.target" ];
      after = [ "systemd-modules-load.service" ];
    };
    storePaths = [ "${config.systemd.package}/lib/systemd/systemd-pcrphase" ];
  };

  # fallback bootloader: systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 7;
  boot.loader.systemd-boot.extraEntries."nixos-uki-latest.conf" = ''
    title UKI
    linux /efi/Linux/nixos-uki-latest.efi
  '';

  # actual "bootloader": directly booting a UKI image
  boot.loader.systemd-boot.extraInstallCommands =
    let
      systemd-boot-signer = pkgs.writeShellApplication {
        name = "systemd-boot-signer";
        runtimeInputs = with pkgs; [ sbctl ];
        text = ''
          set -x
          sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
          sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi
          sbctl sign -s /boot/EFI/nixos/*linux-*-bzImage.efi
        '';
      };

      s255 = inputs.nixpkgs-systemd-255.legacyPackages.x86_64-linux.systemd;
      systemdUkify = s255.override {
        withEfi = true;
        withBootloader = true;
        withCryptsetup = true;
        withUkify = true;
        # 255-only, remove once it's mainlined
        withIptables = false;
        withPasswordQuality = false;
        withVmspawn = false;
        withQrencode = false;
      };
      bootspecNamespace = ''"org.nixos.bootspec.v1"'';

      uki-installer = pkgs.writeShellApplication {
        name = "uki-installer";
        runtimeInputs = with pkgs; [
          binutils coreutils efibootmgr findutils gnugrep jq sbsigntool systemd
        ];

        text = ''
          # extract required data
          boot_json=$(find /nix/var/nix/profiles/system-*-link/boot.json \
                      | sort -V | tail -n1)
          kernel=$(jq -r '.${bootspecNamespace}.kernel' "$boot_json")
          initrd=$(jq -r '.${bootspecNamespace}.initrd' "$boot_json")
          init=$(jq -r '.${bootspecNamespace}.init' "$boot_json")

          # prepare UKI image
          ${systemdUkify}/lib/systemd/ukify build \
            --tools=${pkgs.systemd}/lib/systemd \
            --linux="$kernel" \
            --initrd="$initrd" \
            --os-release="@${config.system.build.etc}/etc/os-release" \
            --cmdline="init=$init ${builtins.toString config.boot.kernelParams}" \
            --stub=${pkgs.systemd}/lib/systemd/boot/efi/linuxx64.efi.stub \
            --secureboot-private-key /etc/secureboot/keys/db/db.key \
            --secureboot-certificate /etc/secureboot/keys/db/db.pem \
            --sign-kernel \
            --pcr-banks=sha256 \
            --measure \
            --output=${config.boot.loader.efi.efiSysMountPoint}/EFI/Linux/nixos-uki-latest.efi \
            | tee /tmp/pcrs
          cp /tmp/pcrs /mnt/persist/pcrs
          h11="$(grep ^11:sha256= /tmp/pcrs | head -n1)"

          # enroll PCR policy into TPM
          ${systemdUkify}/bin/systemd-cryptenroll --tpm2-device=/dev/tpmrm0 \
            --wipe-slot=tpm2 \
            --tpm2-pcrs=0+1+2+3+5+6+7+"$h11"+12 \
            --unlock-key-file=/mnt/persist/secrets/root.key \
            /dev/disk/by-partlabel/QUINCE

          # create a direct boot entry
          [ -e disk=/dev/mmcblk0 ] && DISK=/dev/mmcblk0 || DISK=/dev/mmcblk1
          if ! grep -q 'UKI NixOS' <(efibootmgr); then
            efibootmgr --create --index=0 --disk="$DISK" --part=1 \
              --label='UKI NixOS' --loader='EFI\Linux\nixos-uki-latest.efi'
          fi

          rm /tmp/pcrs
        '';
      };
    in
      ''
      set -e
      ${systemd-boot-signer}/bin/systemd-boot-signer
      ${uki-installer}/bin/uki-installer
    '';

  # locking down
  boot.kernelParams = [ "rd.systemd.gpt_auto=0" ];
  systemd.enableEmergencyMode = false;
  boot.initrd.systemd.emergencyAccess = false;

  environment.persistence."/mnt/persist".directories = [ "/etc/secureboot" ];
}
