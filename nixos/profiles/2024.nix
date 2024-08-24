{ lib, ... }:

# Shared common profile for hosts provisioned in 2024.
#
# Highlights:
# * impermanence is mandatory
# * automatic secrets injection (misc/secrets)
# * disko manages all volumes needed for booting, but not necessarily storage
# * /mnt/storage exists on each host,
#   though unlocking of it can be manual and separate

{
  boot.loader.systemd-boot.netbootxyz.enable = lib.mkDefault true;

  zramSwap = lib.mkDefault { enable = true; memoryPercent = 50; };

  systemd.targets.storage.after = [ "mnt-storage.mount" ];

  users = {
    mutableUsers = false;
    users.monk.hashedPasswordFile = "/mnt/secrets/login/monk";
    users.root.hashedPasswordFile = "/mnt/secrets/login/root";
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    hostKeys =
      [ { path = "/run/credentials/sshd.service/ed25519"; type = "ed25519"; } ];
  };
  systemd.services.sshd.serviceConfig.LoadCredential =
    "ed25519:/mnt/secrets/sshd/ed25519";

  environment.persistence."/mnt/persist" = {
    hideMounts = true;
    directories = [
      "/var/lib/nixos"
      "/var/log"
    ];
    files = [
      "/etc/machine-id"
    ];
    users.monk = {
      directories = [
        ".local/share/pygments-cache"
        ".local/share/xonsh"
      ];
      files = [
        ".bash_history"
      ];
    };
  };
}
