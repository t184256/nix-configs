{ pkgs, inputs, ... }:

let
  hydraPkg = inputs.hydra.defaultPackage.${pkgs.system};
in
{
  # hydra-create-user monk --full-name 'Alexander Sosedkin' \
  #  --email-address 'monk@unboiled.info' --role admin
  # nix-store --generate-binary-cache-key hydra-unboiled-info \
  #   /mnt/persist/var/secrets/nix-cache/priv-key.pem \
  #   /mnt/persist/var/secrets/nix-cache/pub-key.pem
  # chown -R hydra:hydra /mnt/persist/var/secrets/nix-cache
  # chmod 440 /mnt/persist/var/secrets/nix-cache/priv-key.pem
  # psql hydra
  #   ALTER TABLE BuildOutputs ALTER COLUMN path DROP NOT NULL;
  #   ALTER TABLE BuildStepOutputs ALTER COLUMN path DROP NOT NULL;
  #   ALTER TABLE BuildStepOutputs ADD contentAddressed BOOLEAN NOT NULL DEFAULT 'f';

  nix.extraOptions = ''
    trusted-users = monk hydra-queue-runner
    keep-derivations = true
    keep-outputs = true
  '';
  services.hydra = {
    enable = true;
    hydraURL = "https://hydra.unboiled.info";
    notificationSender = "hydra@unboiled.info";
    useSubstitutes = true;
    listenHost = "127.0.0.1";
    port = 4000;
    package = hydraPkg;
    minimumDiskFree = 20;  # GB
    extraConfig = ''
      binary_cache_secret_key_file = /var/secrets/nix-cache/priv-key.pem
    '';
  };
  services.nginx = {
    recommendedProxySettings = true;
    virtualHosts."hydra.unboiled.info" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:4000";
      extraConfig = ''
        proxy_cache off;
      '';
    };
  };

  systemd = {
    timers.flake-autoupdate = {
      wantedBy = [ "timers.target" ];
      partOf = [ "flake-autoupdate.service" ];
      timerConfig.OnCalendar = "0/2:08";  # once in 2 hours, offset by 8 min
    };
    services.flake-autoupdate = {
      serviceConfig.User = "hydra";
      serviceConfig.Type = "oneshot";
      script = ''
        set -uexo pipefail
        export PATH=${pkgs.git}/bin:${pkgs.nix}/bin:$PATH
        WD=/var/lib/flake-autoupdate; mkdir -p $WD
        NEW=$WD/.new-t184256-nix-configs
        FRZ=$WD/.frz-t184256-nix-configs
        OLD=$WD/.old-t184256-nix-configs
        LNK=$WD/t184256-nix-configs
        export GIT_AUTHOR_NAME="Auto Update"
        export GIT_AUTHOR_EMAIL="hydra@unboiled.info"
        export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
        export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
        [[ -e $WD/nixpkgs ]] || \
          ${pkgs.git}/bin/git clone https://github.com/NixOS/nixpkgs $WD/nixpkgs
        pushd $WD/nixpkgs
          ${pkgs.git}/bin/git pull --ff-only
          LAGGING=$(git rev-parse 'master@{2 hours ago}')
        popd
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
            nix flake update --show-trace \
                             --override-input nixpkgs \
                                              github:NixOS/nixpkgs?ref=$LAGGING
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

  environment.persistence."/mnt/persist".directories = [
    {
      directory = "/var/secrets/nix-cache";
      user = "hydra"; group = "hydra";
    }
    {
      directory = "/var/lib/hydra";
      user = "hydra"; group = "hydra";
    }
    {
      directory = "/var/lib/postgresql";
      user = "postgres"; group = "postgres";
    }
    {
      directory = "/var/lib/flake-autoupdate";
      user = "hydra"; group = "hydra";
    }
  ];
}
