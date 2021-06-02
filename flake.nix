{
  description = "t184256's personal configuration files";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-21.05";

    home-manager.url = "github:nix-community/home-manager/release-21.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
  let
    autoimport = (import ./.autoimport);
    common_modules = [ home-manager.nixosModules.home-manager {
                         # false as overlays are pulled in where needed
                         home-manager.useGlobalPkgs = false;
                         home-manager.useUserPackages = true;
                     }] ++
                     [ (_: {
                       home-manager.users.monk =
                               autoimport.merge ./user;
                       # disabled as all overlays are user/-side now
                       # nixpkgs.overlays = autoimport.asList ./overlays;
                     }) ] ++
                     (autoimport.asPaths ./nixos);
  in
  {
    # an example host configuration one can nixos-rebuild from
    nixosConfigurations.flaky = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./hosts/flaky/configuration.nix ] ++ common_modules;
    };
    # another host
    nixosConfigurations.lychee = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./hosts/lychee/configuration.nix ] ++ common_modules;
    };
    nixosModules = {
      nixos = autoimport.asAttrs ./nixos;
    };
  };
}
