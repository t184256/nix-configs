{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../nixos/services/dyndns.nix
    ../../nixos/services/ipfs/cluster-leader.nix
    ../../nixos/services/ipfs/node.nix
    ../../nixos/services/nebula
  ];

  users.mutableUsers = false;
  users.users.monk.hashedPasswordFile = "/mnt/persist/secrets/login/monk";
  users.users.root.hashedPasswordFile = "/mnt/persist/secrets/login/root";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  hardware.cpu.intel.updateMicrocode = true;
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
  hardware.wirelessRegulatoryDatabase = true;

  #zramSwap = { enable = true; memoryPercent = 50; };

  networking.hostName = "cocoa";
  networking.networkmanager.enable = true;
  systemd.network.wait-online.anyInterface = true;

  # Set your time zone.
  time.timeZone = "Europe/Prague";

  services.kubo.settings.Datastore.StorageMax = "20G";

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

  # accept forwarded SSH/MOSH
  networking.firewall.allowedUDPPortRanges = [ { from = 22700; to = 22799; } ];
  services.sshguard.whitelist = [ "192.168.99.2" ];

  #system.noGraphics = true;
  #home-manager.users.monk.system.noGraphics = true;
  system.role = {
    desktop.enable = true;
    physical.enable = true;
    physical.portable = true;
    yubikey.enable = true;
  };
  #home-manager.users.monk = {
  #  services.syncthing.enable = true;
  #};

  system.stateVersion = "23.05";
  home-manager.users.monk.home.stateVersion = "23.05";

  home-manager.users.monk.neovim.fat = true;
  home-manager.users.monk.language-support = [
    "nix" "bash"
  ];

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

  services.displayManager.autoLogin = { enable = true; user = "monk"; };

  boot.kernelPackages = pkgs.linuxPackages_testing;  # needed for bcachefs now
  # currently bcachefs unlocking is broken otherwise
  boot.initrd.systemd.enable = true;

  hardware.display.edid = {
    enable = true;
    modelines = {  # DMT, I guess
       "800x600" = "40 800 840 968 1056 600 601 605 628 -hsync +vsync";
       "1280x720" = "74.50 1280 1344 1472 1664 720 723 728 748 -hsync +vsync";
       "1280x960" = "108 1280 1376 1488 1800 960 961 964 1000 +hsync +vsync";

       "1024x600" = "40.141 1024 1032 1064 1104 600 604 612 618 +hsync -vsync ratio=16:9";  # works! extra 1024x576!
       "1920x600" = "72.72 1920 1928 1960 2000 600 604 612 618 +hsync -vsync ratio=16:9";  # works! extra 1920x1080!
       "2280x1080" = "153.778 2280 2288 2320 2360 1080 1097 1105 1111 +hsync -vsync ratio=16:9";  # works!
       "2208x1786" = "246.006 2208 2216 2248 2288 1786 1823 1831 1837 +hsync -vsync ratio=16:9";  # not detected

       "2048x1536" =   "196.883 2048 2056 2088 2128 1536 1566 1574 1580 +hsync -vsync ratio=16:9";  # works, but as 2048x1152
       "2048x1536_a" = "196.883 2048 2056 2088 2128 1536 1566 1574 1580 +hsync -vsync ratio=5:4";  # not detected
       "2048x1536_b" = "196.883 2048 2056 2088 2128 1536 1566 1574 1580 +hsync -vsync ratio=4:3";  # not detected
       "test_3a" =      "98.441 2048 2056 2088 2128 1536 1544 1552 1558 +hsync -vsync ratio=16:9";  # 2048x1536@30 & 2048x1152@60
       "test_3b" =      "98.441 2048 2056 2088 2128 1536 1544 1552 1558 +hsync -vsync ratio=4:3";  # 2048x1536@30
       "test_cvt" =     "267.25 2048 2200 2424 2800 1536 1539 1543 1592 -hsync +vsync ratio=4:3";  # not detected
       "test_cvt-" =    "267.25 2048 2200 2424 2800 1536 1539 1543 1592 -hsync +vsync ratio=16:9";  # 2048x1152@60
       "test_rb" =      "209.25 2048 2096 2128 2208 1536 1539 1543 1580 +hsync -vsync ratio=4:3";  # not detected
       "test_rb-" =     "209.25 2048 2096 2128 2208 1536 1539 1543 1580 +hsync -vsync ratio=16:9";  # 2048x1152
       "test_rb2" =    "201.734 2048 2056 2088 2128 1536 1566 1574 1580 +hsync -vsync ratio=4:3";  # not detected
       "test_rb2-" =   "201.734 2048 2056 2088 2128 1536 1566 1574 1580 +hsync -vsync ratio=16:9";  # 2048x1152
       "test_i" =      "196.883 2048 2056 2088 2128 1536 1566 1574 1580 -hsync +vsync ratio=4:3";  # not detected
       "test_i-" =     "196.883 2048 2056 2088 2128 1536 1566 1574 1580 -hsync +vsync ratio=16:9";  # 2048x1152

       "test_40" =     "131.255 2048 2056 2088 2128 1536 1551 1559 1565 +hsync -vsync ratio=16:9";  # 2048x1536@40 & 2048x1152@60
       "test_40-" =    "131.255 2048 2056 2088 2128 1536 1551 1559 1565 +hsync -vsync ratio=4:3";  # 2048x1536@40
       "test_45" =     "147.662 2048 2056 2088 2128 1536 1555 1563 1569 +hsync -vsync ratio=16:9";  # 2048x1536@45 & 2048x1152@60
       "test_45-" =    "147.662 2048 2056 2088 2128 1536 1555 1563 1569 +hsync -vsync ratio=4:3";  # 2048x1536@45

       "wmg" =         "196.116 2048 2056 2088 2128 1536 1566 1574 1580 +hsync -vsync ratio=16:9";  # 2048x1152@60
       "wmg2" =        "188.744 2048 2056 2088 2128 1536 1566 1574 1580 +hsync -vsync ratio=16:9";  # 2048x1152@60
       "wmg3" =         "266.95 2048 2200 2424 2800 1536 1537 1540 1589 +hsync -vsync ratio=16:9";  # 2048x1152@60
       "wmg4" =         "287.76 2048 2208 2440 2912 1536 1537 1540 1647 +hsync -vsync ratio=16:9";  # 2048x1152@60
       "Wmg" =         "196.116 2048 2056 2088 2128 1536 1566 1574 1580 +hsync -vsync ratio=4:3";  # not detected
       "Wmg2" =        "188.744 2048 2056 2088 2128 1536 1566 1574 1580 +hsync -vsync ratio=4:3";  # not detected
       "Wmg3" =         "266.95 2048 2200 2424 2800 1536 1537 1540 1589 +hsync -vsync ratio=4:3";  # not detected
       "Wmg4" =         "287.76 2048 2208 2440 2912 1536 1537 1540 1647 +hsync -vsync ratio=4:3";  # not detected

       "2960x1848_3" = "169.085 2960 2968 3000 3040 1848 1860 1868 1874 +hsync -vsync ratio=16:10";  # 912x570@60.049
       "2960x1848_6" = "468.06 2960 3192 3520 4080 1848 1849 1852 1912 -hsync +vsync ratio=16:10";   # 912x570@60.049
       "2960x1848_12" = "988.42 2960 3224 3560 4160 1848 1849 1852 1980 -hsync +vsync ratio=16:10";  # 912x570@60.049
       "2960x1848-3" = "169.085 2960 2968 3000 3040 1848 1860 1868 1874 +hsync -vsync ratio=16:9";  # 912x513@60
       "2960x1848-6" = "468.06 2960 3192 3520 4080 1848 1849 1852 1912 -hsync +vsync ratio=16:9";   # 912x513@60
       "2960x1848-12" = "988.42 2960 3224 3560 4160 1848 1849 1852 1980 -hsync +vsync ratio=16:9";  # 912x513@60

       #"2208x1786" = "337.08 2208 2384 2624 3040 1786 1787 1790 1848 -hsync +vsync ratio=5:4";  # not detected
       #"2880x1800" = "337.75 2880 2928 2960 3040 1800 1803 1809 1852 +hsync -vsync";
       #"2208x1786_6" = "337.08 2208 2384 2624 3040 1786 1787 1790 1848 -hsync +vsync";
       #"2208x1786_12" = "712.55 2208 2408 2656 3104 1786 1787 1790 1913 -hsync +vsync";

       # Detailed Timing Descriptors:
       #   DTD 1:  3840x2160   59.981998 Hz  16:9    133.280 kHz    533.120000 MHz (344 mm x 195 mm)
       #                Hfront   48 Hsync  32 Hback   80 Hpol P
       #                Vfront    3 Vsync   5 Vback   54 Vpol N
       #   Display Product Name: 'HDP-V104'
       #   Display Product Serial Number: 'demoset-1'
       #   Display Range Limits:
       #     Monitor ranges (GTF): 24-144 Hz V, 15-222 kHz H, max dotclock 600 MHz

       "3840x2160_6" = "712.34 3840 4152 4576 5312 2160 2161 2164 2235 -hsync +vsync";  # 3840x2160@4 & 1792x1008@60
       "mimic-rb" = "533 3840 3888 3920 4000 2160 2163 2168 2222 +hsync -vsync";  # 1792x1008@60
       "mimic-cea" = "594 3840 4016 4104 4400 2160 2168 2178 2250 +hsync -vsync";  # 1792x1008@60
    };
  };
  hardware.display.outputs = {
    #"HDMI-A-1".mode = "e";
    #"HDMI-A-1".edid = "2880x1800.bin";
    #"HDMI-A-2".mode = "e";
    #"HDMI-A-2".edid = "800x600.bin";
  };
}
