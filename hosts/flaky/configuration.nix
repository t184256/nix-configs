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
  services.nix-serve = {
    enable = true;
    secretKeyFile = "/var/secrets/nix-cache-priv-key.pem";
  };
  networking.firewall.allowedTCPPorts = [ 3000 5000 ];
  nix.buildMachines = [
    {
      hostName = "localhost";
      system = "x86_64-linux";
      supportedFeatures = ["kvm" "nixos-test" "big-parallel" "benchmark"];
      maxJobs = 2;
    }
  ];
  nix.buildCores = 2;
  boot.tmpOnTmpfs = false;
}
