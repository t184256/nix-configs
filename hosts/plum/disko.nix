{ lib, pkgs, ... }:

let
  # TODO: fancier toml, with names and IPs, possibly? and a custom module
  tangToml = builtins.fromTOML (builtins.readFile ../../misc/pubkeys/tang.toml);
  tangThpQuince = tangToml.quince;

  # Two HDDs, identical layout:
  #   p1 32G  hdd-swap-<x>  LUKS, swap (the only swap on the system)
  #   p2 92G  hdd-fast-<x>  LUKS, btrfs RAID0 -> /mnt/hdd/fast
  #   p3 rest hdd-slow-<x>  LUKS, btrfs RAID0 -> /mnt/hdd/slow
  # TODO: consider switching to bcachefs later and carving out a bit of NVMe.

  mkHDD =
    { device, suffix }:
    {
      type = "disk";
      inherit device;
    content = {
      type = "gpt";
      partitions = {
        hdd-swap = {
          size = "32G";
          content = {
            type = "luks";
            name = "hdd-swap-${suffix}";
            # tolerate a missingDrive
            settings = { crypttabExtraOpts = [ "nofail" ]; };
            content = {
              type = "swap";
              randomEncryption = false;  # already on LUKS
              priority = 1;
            };
          };
        };
        hdd-fast = {
          size = "92G";
          content = {
            type = "luks";
            name = "hdd-fast-${suffix}";
            settings = { crypttabExtraOpts = [ "nofail" ]; };
            postCreateHook = lib.optionalString (suffix == "b") ''
              # disko has no multi-device btrfs; guard against reformats
              if ! blkid /dev/mapper/hdd-fast-a | grep -q '^TYPE=btrfs'; then
                mkfs.btrfs -d raid0 -m raid0 \
                  /dev/mapper/hdd-fast-a /dev/mapper/hdd-fast-b
              fi
            '';
          };
        };
        hdd-slow = {
          size = "100%";
          content = {
            type = "luks";
            name = "hdd-slow-${suffix}";
            settings = { crypttabExtraOpts = [ "nofail" ]; };
            postCreateHook = lib.optionalString (suffix == "b") ''
              # disko has no multi-device btrfs; guard against reformats
              if ! blkid /dev/mapper/hdd-slow-a | grep -q '^TYPE=btrfs'; then
                mkfs.btrfs -d raid0 -m raid0 \
                  /dev/mapper/hdd-slow-a /dev/mapper/hdd-slow-b
              fi
            '';
          };
        };
      };
    };
  };
in

{
  # initrd closes them as they're unused; the passphrase gets reused
  environment.etc."crypttab".text = ''
    hdd-swap-a /dev/disk/by-partlabel/disk-hdd-a-hdd-swap - nofail
    hdd-swap-b /dev/disk/by-partlabel/disk-hdd-b-hdd-swap - nofail
    hdd-fast-a /dev/disk/by-partlabel/disk-hdd-a-hdd-fast - nofail
    hdd-fast-b /dev/disk/by-partlabel/disk-hdd-b-hdd-fast - nofail
    hdd-slow-a /dev/disk/by-partlabel/disk-hdd-a-hdd-slow - nofail
    hdd-slow-b /dev/disk/by-partlabel/disk-hdd-b-hdd-slow - nofail
  '';

  # can't define in disko because multidevice
  fileSystems = {
    "/mnt/hdd/fast" = {
      device = "/dev/mapper/hdd-fast-a";
      fsType = "btrfs";
      options = [ "noatime" "nofail" ];
    };
    "/mnt/hdd/slow" = {
      device = "/dev/mapper/hdd-slow-a";
      fsType = "btrfs";
      options = [ "noatime" "nofail" ];
    };
  };

  disko.devices = {
    disk = {
      plum-main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_1TB_S7U4NU1YB17701K_1";
        content = {
          type = "gpt";
          partitions = {
            BOOT = {
              size = "768M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "defaults" ];
              };
            };
            ROOT = {
              size = "100%";
              content = {
                type = "luks";
                name = "root";
                settings.allowDiscards = true;
                additionalKeyFiles = [ "/tmp/root.luks" ];
                postMountHook = ''
                  tmpdir=$(mktemp -d)
                  mount -o subvol=/secrets /dev/mapper/$name "$tmpdir"
                  ${pkgs.clevis}/bin/clevis encrypt tang \
                    '{"url":"http://192.168.98.1:1449","thp":"${tangThpQuince}"}' \
                    < /tmp/root.luks > "$tmpdir/clevis"
                  umount "$tmpdir"
                  rmdir "$tmpdir"
                '';
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];  # overwrite existing
                  subvolumes = {
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = [ "noatime" ];
                    };
                    "/secrets" = {
                      mountpoint = "/mnt/secrets";
                      mountOptions = [ "noatime" ];
                    };
                    "/persist" = {
                      mountpoint = "/mnt/persist";
                      mountOptions = [ "noatime" ];
                    };
                    "/storage" = {
                      mountpoint = "/mnt/storage";
                      mountOptions = [ "noatime" ];
                    };
                    # HDD-only swap now
                    # "/swap" = {
                    #   mountpoint = "/var/swap";
                    #   mountOptions = [ "noatime" ];
                    # };
                  };
                };
              };
            };
          };
        };
      };
      hdd-a = mkHDD {
        suffix = "a";
        device = "/dev/disk/by-id/ata-ST500LM021-1KJ152_W62HE649";
      };
      hdd-b = mkHDD {
        suffix = "b";
        device = "/dev/disk/by-id/ata-ST500LM021-1KJ152_W62MV65Q";
      };
    };
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = [ "size=1024M" "mode=755" ];
      };
    };
  };
}
