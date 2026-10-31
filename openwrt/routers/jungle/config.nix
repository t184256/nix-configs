{ config, lib, ... }: {
  uci.packageManager = "apk";
  uci.packages = [
    "ethtool"  # device quirk, same stuff as on bootstrap
    "python3-light" "python3-cryptography"  # on-device-secrets, bootstrap
  ];
  uci.sshKeys = [ (builtins.readFile ../../../misc/pubkeys/ssh) ];

  uci.files = [
    # same stuff as in bootstrap
    {
      path = "/usr/mtd.layout";
      content = builtins.readFile ./mtd.layout;
    }
    {
      path = "/usr/sbin/on-device-secrets";
      executable = true;
      content = builtins.readFile ../../common/on-device-secrets;
    }
    {
      path = "/usr/local/python-modules/age.py";
      content = builtins.readFile (import ../../common/python-age.nix);
    }
    # MT7987 + RTL8221B: EEE breaks TX (openwrt/openwrt#20967); netifd's eee
    # option does nothing, so tx-lpi it. kept in sync with bootstrap.
    {
      path = "/etc/rc.local";
      executable = true;
      content = ''
        # /etc/rc.local for the jungle: MT7987 + RTL8221B EEE breaks TX
        # (openwrt/openwrt#20967); netifd's eee option is a no-op, so tx-lpi it.
        # written by bootstrap and kept declaratively by config.nix.
        /usr/sbin/ethtool --set-eee eth0 eee off tx-lpi off ||:
        /usr/sbin/ethtool --set-eee eth1 eee off tx-lpi off ||:
        exit 0
        '';
    }
  ];
}
