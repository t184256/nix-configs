{ pkgs, ... }:

{
  systemd.services."sccache-setup-subvolume" = {
    requires = [ "mnt-hdd-fast.mount" ];
    after = [ "mnt-hdd-fast.mount" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [ coreutils util-linux btrfs-progs ];
    script = ''
      set -Eeuxo pipefail; shopt -s inherit_errexit
      mountpoint -q /mnt/hdd/fast
      [[ -e /mnt/hdd/fast/sccache ]] || \
        btrfs subvol create /mnt/hdd/fast/sccache
      chown monk:users /mnt/hdd/fast/sccache
    '';
  };

  # the user side of the ordeal depends on it
  home-manager.users.monk.systemd.user.services.sccache = {
    Unit.RequiresMountsFor = [ "/mnt/hdd/fast" ];
  };
  home-manager.users.monk.systemd.user.targets."sccache-subvolume.path" = {
    Unit.Description = "Start sccache when its subvolume appears";
    Path.PathExists = [ "/mnt/hdd/fast/sccache" ];
    Path.Unit = [ "sccache.service" ];
    Install.WantedBy = [ "default.target" ];
  };
}
