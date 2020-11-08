{
  description = "t184256's personal configuration files";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-20.09";

    home-manager.url = "github:rycee/home-manager/release-20.09";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
  let autoimport = (import ./.autoimport); in
  {
    # an example host configuration one can nixos-rebuild from
    nixosConfigurations.flaky = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./hosts/flaky/configuration.nix ] ++
                [ home-manager.nixosModules.home-manager {
                    home-manager.useGlobalPkgs = true;
                    home-manager.useUserPackages = true;
                }] ++
                [ (_: {
                  home-manager.users.monk =
                          autoimport.merge ./user;
                  nixpkgs.overlays = autoimport.asList ./overlays;
                }) ] ++
                (autoimport.asPaths ./nixos);
    };
    nixosModules = {
      nixos = autoimport.asAttrs ./nixos;
    };
  };
}
