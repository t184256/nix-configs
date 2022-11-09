{ config, pkgs, inputs, ... }:

{
  imports = [
    "${inputs.nixos-hardware}/onenetbook/4"
    ./hardware-configuration.nix
    ../lychee/onemix-keyboard-remap.nix
  ];

  users.mutableUsers = false;
  users.users.monk.passwordFile = "/mnt/persist/secrets/login/monk";
  users.users.root.passwordFile = "/mnt/persist/secrets/login/root";

  boot.loader.systemd-boot.configurationLimit = 10;  # small-ish /boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  hardware.cpu.intel.updateMicrocode = true;
  hardware.opengl.extraPackages = [ pkgs.intel-media-driver ];
  hardware.wirelessRegulatoryDatabase = true;

  #services.logind.lidSwitch = "suspend-then-hibernate";
  #systemd.sleep.extraConfig = "HibernateDelaySec=90m";

  #zramSwap = { enable = true; memoryPercent = 50; };

  networking.hostName = "jujube";
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Prague";

  # Enable sound with pipewire.
  #sound.enable = true;
  #hardware.pulseaudio.enable = false;
  #security.rtkit.enable = true;
  #services.pipewire = {
  #  enable = true;
  #  alsa.enable = true;
  #  alsa.support32Bit = true;
  #  pulse.enable = true;
  #};

  #home-manager.users.monk.home.packages = with pkgs; [
  #  inputs.deploy-rs.defaultPackage.${pkgs.system}
  #];

  services.openssh.enable = true;

  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  system.role = {
    desktop.enable = true;
    physical.enable = true;
    physical.portable = true;
    yubikey.enable = true;
  };
  #home-manager.users.monk = {
  #  services.syncthing.enable = true;
  #};

  system.stateVersion = "22.05";
  home-manager.users.monk.home.stateVersion = "22.05";

  #home-manager.users.monk.language-support = [
  #  "nix" "bash"
  #];

  environment.persistence."/mnt/persist" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/etc/NetworkManager"
      "/var/lib/NetworkManager"
    #  "/var/lib/alsa"
    #  "/var/lib/bluetooth"
    #  "/var/lib/boltd"
    #  "/var/lib/systemd"
    #  "/var/lib/upower"
    #  "/var/lib/waydroid"
      "/var/log"
    ];
    files =
      (let mode = { mode = "0700"; }; in [
        { file = "/etc/ssh/ssh_host_rsa_key"; parentDirectory = mode; }
        { file = "/etc/ssh/ssh_host_rsa_key.pub"; parentDirectory = mode; }
        { file = "/etc/ssh/ssh_host_ed25519_key"; parentDirectory = mode; }
        { file = "/etc/ssh/ssh_host_ed25519_key.pub"; parentDirectory = mode; }
      ]) ++ [
        "/etc/machine-id"
      ];
    # TODO: allowlisting of ~
  };

  environment.systemPackages = with pkgs; [ keyutils ];

  boot.initrd.extraUtilsCommands = ''
    copy_bin_and_libs ${pkgs.bcachefs-tools}/bin/bcachefs
    copy_bin_and_libs ${pkgs.gnupg}/bin/gpg
    copy_bin_and_libs ${pkgs.gnupg}/bin/gpg-card
    copy_bin_and_libs ${pkgs.gnupg}/bin/gpg-agent
    copy_bin_and_libs ${pkgs.gnupg}/libexec/scdaemon
    copy_bin_and_libs ${pkgs.keyutils}/bin/keyctl
    mkdir $out/secrets
    cat ${../../misc/pubkey.pgp} > $out/secrets/pubkey.pgp
  '';
  boot.initrd.postDeviceCommands = ''
    mkdir -p /crypt-ramfs /boot
    mount -t ramfs none /crypt-ramfs
    mount -o ro /dev/disk/by-partlabel/JUJUBE_BOOT /boot
    cp -v /boot/key.gpg /crypt-ramfs/key.gpg
    umount /boot

    export GPG_TTY=$(tty)
    export GNUPGHOME=/crypt-ramfs/.gnupg
    gpg-agent --daemon --scdaemon-program $out/bin/scdaemon
    gpg_agent_pid=$$

    gpg --import /pubkey.pgp
    gpg --card-status > /crypt-ramfs/cardstatus
    if [[ $? != 0 ]]; then
        echo 'waiting for GPG card...'
        sleep 2
        echo 'retrying...'
        gpg --card-status > /crypt-ramfs/cardstatus
    fi
    grep -E '^(Serial|Name|Encryption)' /crypt-ramfs/cardstatus

    stty -echo
    echo -n 'Yubikey PIN: '
    if ! gpg --batch --passphrase-fd 0 --pinentry-mode loopback -d \
             /crypt-ramfs/key.gpg > /crypt-ramfs/key; then
        read -rsp 'Passphrase: ' ENCRYPTION_PASSPHRASE
        echo -n "$ENCRYPTION_PASSPHRASE" > /crypt-ramfs/key
    fi
    keyctl padd user cryptsetup @u < /crypt-ramfs/key
    stty echo

    ls /dev/disk/by*label /dev/disk/nvme* /crypt-ramfs || true
    echo -n 'unlocking root filesystem...'
    if ! bcachefs unlock /dev/disk/by-partlabel/JUJUBE </crypt-ramfs/key
    then
      echo -n 'automatic unlock failed. manual unlock: '
      if ! bcachefs unlock /dev/disk/by-partlabel/JUJUBE; then
        echo failed.
      fi
    fi

    kill $gpg_agent_pid
    rm -f /crypt-ramfs/key.gpg /crypt-ramfs/key
    if ! umount /crypt-ramfs; then
      echo 'forcing umount /crypt-ramfs...'
      umount -l /crypt-ramfs
      echo $?
    fi
    alias bcachefs=true  # prevent standard bcachefs.nix prompt from appearing
  '';
}
