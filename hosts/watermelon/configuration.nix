_:

{
  networking.hostName = "watermelon";

  imports = [
    ../../nixos/profiles/2024.nix
    ./disko.nix
    ./hardware.nix
    ./network.nix
    ../../nixos/services/garage.nix
    ../../nixos/services/dns.nix
    ../../nixos/services/nebula ../../nixos/services/nebula/2024.nix
    ../../nixos/services/syncthing.nix
    ../../nixos/services/yousable.nix
  ];

  boot.loader.grub.enable = true;  # sigh

  nixpkgs.flake.setNixPath = false;  # save disk space
  nixpkgs.flake.setFlakeRegistry = false;  # save disk space

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;

  home-manager.users.monk.home.stateVersion = "24.05";
  system.stateVersion = "24.05";
}
