{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.system.role.buildserver;
in {
  options = {
    system.role.buildserver.enable = mkOption {
      default = false;
      example = true;
      description = ''
        Enable some sensible settings for a large-storage'd build box.
      '';
      type = types.bool;
    };
    system.role.buildserver.aarch64.enable = mkOption {
      default = false;
      example = true;
      description = ''
        Enable what's required to act as a build server
        for a Nix-on-Droid aarch64 device.
        https://github.com/t184256/nix-on-droid/wiki/Simple-remote-building
      '';
      type = types.bool;
    };
    system.role.buildserver.hydra.enable = mkOption {
      default = false;
      example = true;
      description = ''
        Enable a Hydra build server.
      '';
      type = types.bool;
    };
    system.role.buildserver.nix-serve.enable = mkOption {
      default = false;
      example = true;
      description = ''
        Publish a nix cache over HTTP.
        Warning: requires secrets to actually run,
        nix-store --generate-binary-cache-key nix-cache-1 \
            /var/secrets/nix-cache-pub-key.pem \
            /var/secrets/nix-cache-priv-key.pem
        chown nix-build:root /var/secrets/nix-cache-priv-key.pem
        chmod 400 /var/secrets/nix-cache-priv-key.pem
      '';
      type = types.bool;
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      nix.extraOptions = ''
        trusted-users = monk hydra-queue-runner
        keep-derivations = true
        keep-outputs = true
      '';
    })
    (mkIf cfg.aarch64.enable {
      boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
    })
    (mkIf cfg.hydra.enable {
      services.hydra = {
        enable = true;
        hydraURL = "https://hydra.unboiled.info";
        notificationSender = "hydra@localhost";
        useSubstitutes = true;
        port = 3000;
        #debugServer = true;
        #extraConfig = ''
        #  #store_uri = file:///nix/store?secret-key=/var/secrets/nix-cache-priv-key.pem
        #  binary_cache_secret_key_file = /var/secrets/nix-cache-priv-key.pem
        #  binary_cache_dir = /nix/store
        #'';
      };
      networking.firewall.allowedTCPPorts = [ 3000 ];
    })
    (mkIf cfg.nix-serve.enable {
      services.nix-serve = {
        enable = true;
        secretKeyFile = "/var/secrets/nix-cache-priv-key.pem";
        port = 5000;
      };
      networking.firewall.allowedTCPPorts = [ 5000 ];
    })
  ];
}
