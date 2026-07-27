_ :

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      fig = { User = "monk"; Hostname = "fig.unboiled.info"; };
      mango = { User = "monk"; Hostname = "mango.unboiled.info"; };
      duckweed = { User = "monk"; Hostname = "duckweed.unboiled.info"; };
      loquat = { User = "monk"; Hostname = "loquat.unboiled.info"; };
      jungle = { User = "root"; Hostname = "jungle.lan"; };
      bayroot = { User = "monk"; Hostname = "192.168.99.3"; };
      araceae = { User = "monk"; Hostname = "192.168.99.4"; };
      quince = { User = "monk"; Hostname = "duckweed.unboiled.info";
                Port = 226; };
      spondias = { User = "monk"; Hostname = "192.168.99.51"; };
      cocoa = { User = "monk"; Hostname = "duckweed.unboiled.info";
                Port = 227; };
      grapefruit = { User = "monk"; Hostname = "192.168.99.52"; };
      plum = { User = "monk"; Hostname = "192.168.99.53"; };
      sloe = { User = "monk"; Hostname = "sloe.unboiled.info"; };
      olosapo = { User = "monk"; Hostname = "olosapo.unboiled.info"; };
      watermelon = { User = "monk"; Hostname = "watermelon.unboiled.info"; };
      etrog = { User = "monk"; Hostname = "etrog.unboiled.info"; };
      iyokan = { User = "monk"; Hostname = "iyokan.unboiled.info"; };

      bayroot64 = {
        User = "monk";
        Hostname = "bayroot.unboiled.info";
        ProxyJump = "duckweed";
      };
      araceae64 = {
        User = "monk";
        Hostname = "araceae.unboiled.info";
        ProxyJump = "duckweed";
      };

      slopfest = {
        User = "sloppy";
        Hostname = "qemu:system/slopfest";
        ProxyCommand =
          "ssh -T plum '" +
          " cid=$(virsh -c qemu:///system dumpxml slopfest" +
          " | xmllint --xpath \"string(//cid/@address)\" -);" +
          " exec ncat --vsock $cid 22" +
          "'"
        ;
        ProxyUseFdpass = "no";
        CheckHostIP = false;
        UserKnownHostsFile = "~/.ssh/slopfest.known_host";
      };
    };
  };
}
