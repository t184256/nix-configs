{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub = { enable = true; version = 2; device = "/dev/sda"; };

  networking = {
    hostName = "flaky"; # Define your hostname.
    interfaces.ens3 = {
      useDHCP = false;
      ipv4.addresses = [ { address = "192.168.100.220"; prefixLength = 24; } ];
    };
    defaultGateway = "192.168.100.1";
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
  };

  time.timeZone = "Europe/Prague";

  environment.systemPackages = with pkgs; [
  ];

  services.openssh.enable = true;

  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  users.users.monk = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  system.stateVersion = "20.09";
  home-manager.users.monk.home.stateVersion = "20.09";

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;

  home-manager.users.monk.language-support = [ "nix" "bash" ];

  system.role.buildserver.enable = true;
  system.role.buildserver.aarch64.enable = true;
  system.role.buildserver.hydra.enable = true;
  system.role.buildserver.nix-serve.enable = true;
  nix.buildMachines = [ {
    hostName = "localhost";
    system = "x86_64-linux";
    supportedFeatures = ["kvm" "nixos-test" "big-parallel" "benchmark"];
    maxJobs = 1;
  } ];
  nix.buildCores = 2;  # we're not in a hurry, and this way we don't swap much
  boot.tmpOnTmpfs = false;  # large builds are, well, large =(
  nix.gc.automatic = true;
  nix.autoOptimiseStore = true;

  systemd = {
    timers.flake-autoupdate = {
      wantedBy = [ "timers.target" ];
      partOf = [ "flake-autoupdate.service" ];
      timerConfig.OnCalendar = "*:08/10";  # once in 10 minutes, offset by 8
    };
    services.flake-autoupdate = {
      serviceConfig.Type = "oneshot";
      script = ''
        set -uexo pipefail
        export PATH=${pkgs.git}/bin:${pkgs.nixFlakes}/bin:$PATH
        WD=/var/lib/autoupdate; mkdir -p $WD
        NEW=$WD/.new-t184256-nix-configs
        FRZ=$WD/.frz-t184256-nix-configs
        OLD=$WD/.old-t184256-nix-configs
        LNK=$WD/t184256-nix-configs
        export GIT_AUTHOR_NAME="Auto Update"
        export GIT_AUTHOR_EMAIL="flake-autoupdate.service@flaky"
        export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
        export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
        [[ -e $NEW ]] && rm -rf $NEW
        [[ -e $OLD ]] && { cp -r $OLD $FRZ; ln -sfn $FRZ $LNK; }
        ${pkgs.git}/bin/git clone https://github.com/t184256/nix-configs $NEW \
                                  --reference-if-able $OLD --dissociate
        rm -rf $OLD
        pushd $NEW
          for branch in main staging; do
            git checkout $branch
            git checkout -b $branch-autoupdate
            time=$(date +%FT%T)
            nix flake update
            if [[ -n "$(git status --porcelain)" ]]; then
              git add flake.lock
              git commit -m "AUTOUPDATE $branch $time"
            else
              echo "no updates found for $branch $time"
            fi
          done
        popd
        mv $NEW $OLD; ln -sfn $OLD $LNK; rm -rf $FRZ $NEW
      '';
    };
  };
}
