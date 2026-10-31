{ config, lib, ... }: {
  uci.packageManager = "apk";
  uci.packages = [ "ethtool" ];
  uci.sshKeys = [ (builtins.readFile ../../../misc/pubkeys/ssh) ];

  uci.files = [
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
