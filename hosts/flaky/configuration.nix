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
    maxJobs = 2;
  } ];
  nix.buildCores = 2;  # we're not in a hurry, and this way we don't swap much
  boot.tmpOnTmpfs = false;  # large builds are, well, large =(
}
