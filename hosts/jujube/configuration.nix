{ config, pkgs, inputs, ... }:

{
  imports = [
    # v bcachefs/kernel module conflict I'm too lazy to resolve right now
    #"${inputs.nixos-hardware}/onenetbook/4"
    ./hardware-configuration.nix
    ../lychee/onemix-keyboard-remap.nix
  ];

  users.mutableUsers = false;
  users.users.monk.hashedPasswordFile = "/mnt/persist/secrets/login/monk";
  users.users.root.hashedPasswordFile = "/mnt/persist/secrets/login/root";

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
      "/var/lib/nixos"
    #  "/var/lib/alsa"
    #  "/var/lib/bluetooth"
    #  "/var/lib/boltd"
    #  "/var/lib/systemd"
    #  "/var/lib/upower"
    #  "/var/lib/waydroid"
      "/var/log"
    ];
    files =
      (let mode = { mode = "0755"; }; in [
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

  services.xserver.displayManager.autoLogin = { enable = true; user = "monk"; };

  boot.initrd.luks.forceLuksSupportInInitrd = true;
  boot.initrd.extraUtilsCommands = ''
    copy_bin_and_libs ${pkgs.bcachefs-tools}/bin/bcachefs
    copy_bin_and_libs ${pkgs.gnupg}/bin/gpg
    copy_bin_and_libs ${pkgs.gnupg}/bin/gpg-card
    copy_bin_and_libs ${pkgs.gnupg}/bin/gpg-agent
    copy_bin_and_libs ${pkgs.gnupg}/libexec/scdaemon
    copy_bin_and_libs ${pkgs.keyutils}/bin/keyctl
    copy_bin_and_libs ${pkgs.cryptsetup}/bin/cryptsetup
    mkdir $out/secrets
    cat ${../../misc/pubkey.pgp} > $out/secrets/pubkey.pgp
  '';
  boot.initrd.postDeviceCommands = ''
    mkdir -p /crypt-ramfs /boot
    mount -t ramfs none /crypt-ramfs
    mount -o ro /dev/disk/by-partlabel/JUJUBE_BOOT /boot
    cp -v /boot/key.gpg /crypt-ramfs/key.gpg
    umount /boot & umount_pid=$$

    export GPG_TTY=$(tty)
    export GNUPGHOME=/crypt-ramfs/.gnupg
    gpg-agent --daemon --scdaemon-program $out/bin/scdaemon & gpg_agent_pid=$$

    gpg --import /pubkey.pgp & gpg_import_pid=$$
    gpg --card-status > /crypt-ramfs/cardstatus
    if [[ $? != 0 ]]; then
        echo 'waiting for GPG card for extra half a second...'
        sleep .5
        echo 'retrying...'
        gpg --card-status > /crypt-ramfs/cardstatus
    fi
    grep -E '^(Serial|Name|Encryption)' /crypt-ramfs/cardstatus
    echo 'waiting for gpg import to complete...'
    wait $gpg_import_pid
    echo 'gpg import completed.'

    stty -echo
    echo -n 'Yubikey PIN: '
    if ! gpg --batch --passphrase-fd 0 --pinentry-mode loopback -d \
             /crypt-ramfs/key.gpg > /crypt-ramfs/key; then
        read -rsp 'Passphrase: ' ENCRYPTION_PASSPHRASE
        echo -n "$ENCRYPTION_PASSPHRASE" > /crypt-ramfs/key
    fi
    kill $gpg_agent_pid  # note the second kill later on
    keyctl padd user cryptsetup @u < /crypt-ramfs/key & keyctl_pid=$$
    stty echo

    echo 'unlocking swap...'
    cryptsetup -q open /dev/disk/by-partlabel/JUJUBE_SWAP JUJUBE_SWAP \
      -d /crypt-ramfs/key & swap_unlock_pid=$$

    echo 'unlocking root filesystem...'
    if ! bcachefs unlock /dev/disk/by-partlabel/JUJUBE </crypt-ramfs/key
    then
      echo -n 'automatic unlock failed. manual unlock: '
      if ! bcachefs unlock /dev/disk/by-partlabel/JUJUBE; then
        echo failed.
      fi
    fi
    echo 'unlocking root filesystem has completed.'

    kill -9 $gpg_agent_pid
    echo 'waiting for /boot umount...'
    wait $umount_pid
    echo 'waiting for keyctl injection...'
    wait $keyctl_pid
    echo 'waiting for swap unlocking...'
    wait $swap_unlock_pid
    echo 'waiting for gpg-agent...'
    wait $gpg_agent_pid
    echo 'waiting completed.'

    echo 'cleaning up...'
    rm -f /crypt-ramfs/key.gpg /crypt-ramfs/key
    if ! umount /crypt-ramfs; then
      echo 'forcing umount /crypt-ramfs...'
      umount -l /crypt-ramfs
    fi
    alias bcachefs=true  # prevent standard bcachefs.nix prompt from appearing
    echo 'proceeding to boot...'
  '';
}
