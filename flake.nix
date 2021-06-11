{
  description = "t184256's personal configuration files";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.05";

    nixos-hardware.url = "github:t184256/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-21.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    alacritty-autoresizing = {
      url = "github:t184256/alacritty-autoresizing";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    home-manager,
    alacritty-autoresizing,
    ...
  }@inputs:
  let
    autoimport = (import ./.autoimport);
    specialArgs = { inherit inputs; };
    common_modules = [ home-manager.nixosModules.home-manager {
                         # false as overlays are pulled in where needed
                         home-manager.useGlobalPkgs = false;
                         home-manager.useUserPackages = true;
                         home-manager.extraSpecialArgs = specialArgs;
                     }] ++
                     [ (_: {
                       home-manager.users.monk =
                               autoimport.merge ./user;
                       # disabled as all overlays are user/-side now
                       # nixpkgs.overlays = autoimport.asList ./overlays;
                     }) ] ++
                     (autoimport.asPaths ./nixos);
    mkSystem = system: hostcfg:
      nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [ hostcfg ] ++ common_modules;
      };
  in
  {
    nixosConfigurations = {
      flaky = mkSystem "x86_64-linux" ./hosts/flaky/configuration.nix;
      lychee = mkSystem "x86_64-linux" ./hosts/lychee/configuration.nix;
    };
    nixosModules = {
      nixos = autoimport.asAttrs ./nixos;
    };
  };
}
