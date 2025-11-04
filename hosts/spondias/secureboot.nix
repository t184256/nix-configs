{ pkgs, lib, config, inputs, ... }:

{
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
    storePaths = [ "${config.systemd.package}/lib/systemd/systemd-pcrextend" ];
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
      fingerprinter = pkgs.writeShellApplication {
        name = "fingerprinter";
        runtimeInputs = with pkgs; [
          coreutils findutils gnutar efibootmgr jq
        ];

        text = ''
          set -Eeuo pipefail; shopt -s inherit_errexit
          boot_json=$(find /nix/var/nix/profiles/system-*-link/boot.json \
                      | sort -V | tail -n1)
          kernel=$(jq -r '.${bootspecNamespace}.kernel' "$boot_json")
          initrd=$(jq -r '.${bootspecNamespace}.initrd' "$boot_json")
          init=$(jq -r '.${bootspecNamespace}.init' "$boot_json")
          echo ${pkgs.systemd}
          efibootmgr
          ${systemdUkify}/lib/systemd/systemd-pcrlock --json=pretty \
            2>/dev/null| sha256sum
          cat "$boot_json"
          cat "${config.system.build.etc}/etc/os-release"
          echo "${builtins.toString config.boot.kernelParams}"
          sha256sum "$kernel"
          sha256sum "$initrd"
          sha256sum "$init"
          sha256sum "${pkgs.systemd}/lib/systemd/boot/efi/linuxx64.efi.stub"
          tar c /mnt/secrets/secureboot 2>/dev/null | sha256sum
        '';
      };

      systemd-boot-signer = pkgs.writeShellApplication {
        name = "systemd-boot-signer";
        runtimeInputs = with pkgs; [ sbctl ];
        text = ''
          set -Eeuo pipefail; shopt -s inherit_errexit
          rm -rf /var/lib/sbctl
          mkdir -p /var/lib/sbctl
          sbctl import-keys --directory /mnt/secrets/secureboot
          sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
          sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi
          sbctl sign -s /boot/EFI/nixos/*linux-*-bzImage.efi
          rm -rf /var/lib/sbctl
        '';
      };

      systemdUkify = pkgs.systemd.override {
        withEfi = true;
        withBootloader = true;
        withCryptsetup = true;
        withUkify = true;
      };
      bootspecNamespace = ''"org.nixos.bootspec.v1"'';

      uki-installer = pkgs.writeShellApplication {
        name = "uki-installer";
        runtimeInputs = with pkgs; [
          binutils coreutils efibootmgr findutils gnugrep jq sbsigntool systemd
        ];

        text = ''
          set -Eeuo pipefail; shopt -s inherit_errexit
          # extract required data
          boot_json=$(find /nix/var/nix/profiles/system-*-link/boot.json \
                      | sort -V | tail -n1)
          kernel=$(jq -r '.${bootspecNamespace}.kernel' "$boot_json")
          initrd=$(jq -r '.${bootspecNamespace}.initrd' "$boot_json")
          init=$(jq -r '.${bootspecNamespace}.init' "$boot_json")

          # prepare UKI image
          h11="$(${systemdUkify}/lib/systemd/ukify build \
            --tools=${pkgs.systemd}/lib/systemd \
            --linux="$kernel" \
            --initrd="$initrd" \
            --os-release="@${config.system.build.etc}/etc/os-release" \
            --cmdline="init=$init ${builtins.toString config.boot.kernelParams}" \
            --stub=${pkgs.systemd}/lib/systemd/boot/efi/linuxx64.efi.stub \
            --secureboot-private-key /mnt/secrets/secureboot/db/db.key \
            --secureboot-certificate /mnt/secrets/secureboot/db/db.pem \
            --sign-kernel \
            --pcr-banks=sha256 \
            --measure \
            --output=${config.boot.loader.efi.efiSysMountPoint}/EFI/Linux/nixos-uki-latest.efi.tmp \
            )"
            grep -q ^11:sha256= <<<"$h11"
            h11="$(<<<"$h11" grep ^11:sha256= | head -n1)"

          # enroll PCR policy into TPM (hint: start with just PCR 11)
          ${systemdUkify}/bin/systemd-cryptenroll --tpm2-device=/dev/tpmrm0 \
            --wipe-slot=tpm2 \
            --tpm2-pcrs=0+1+2+3+5+6+7+"$h11"+12 \
            --unlock-key-file=/mnt/secrets/root.luks \
            /dev/disk/by-partlabel/disk-spondias-main-ROOT

          mv \
            "${config.boot.loader.efi.efiSysMountPoint}/EFI/Linux/nixos-uki-latest.efi.tmp" \
            "${config.boot.loader.efi.efiSysMountPoint}/EFI/Linux/nixos-uki-latest.efi"

          # create a direct boot entry
          DISK=/dev/disk/by-id/ata-SAMSUNG_MZ7LH128HBHQ-000L1_S4VNNF0MC43551
          if ! grep -Fq 'UKI NixOS' <(efibootmgr); then
            efibootmgr --create --index=0 --disk="$DISK" --part=1 \
              --label='UKI NixOS' --loader='EFI\Linux\nixos-uki-latest.efi'
            efibootmgr
          fi

        '';
      };
    in
      ''
      set -Eeuo pipefail; shopt -s inherit_errexit
      fprint="$(${fingerprinter}/bin/fingerprinter)"
      fprintfile='/mnt/persist/var/lib/secureboot'
      mkdir -p $(dirname "$fprintfile")

      if [[ ! -e "$fprintfile" || "$(cat "$fprintfile")" != "$fprint" ]]; then
        ${pkgs.diffutils}/bin/diff -U1 - <<<"$fprint" "$fprintfile" || true
        echo 'Updating and re-signing UKI...'
        ${systemd-boot-signer}/bin/systemd-boot-signer
        ${uki-installer}/bin/uki-installer
        echo "$fprint" > "$fprintfile"
        chmod 600 "$fprintfile"
      else
        echo 'No need to update and re-sign UKI, I hope'
      fi
    '';

  # locking down
  systemd.enableEmergencyMode = false;
  boot.initrd.systemd.emergencyAccess = false;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "rd.systemd.gpt_auto=0"
    "quiet" "loglevel=4"
  ];

  # debugging
  #boot.initrd.systemd.extraConfig = ''
  #  LogLevel=debug
  #  StatusUnitFormat=combined
  #  DefaultTimeoutStartSec=10
  #  DefaultTimeoutStopSec=10
  #'';

}
