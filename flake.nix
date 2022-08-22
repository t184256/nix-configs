{
  description = "t184256's personal configuration files";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";

    impermanence.url = "github:nix-community/impermanence";
    impermanence.inputs.nixpkgs.follows = "nixpkgs";

    simple-nixos-mailserver.url =
      "gitlab:simple-nixos-mailserver/nixos-mailserver";
    simple-nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixgl.url = "github:guibou/nixGL";
    nixgl.inputs.nixpkgs.follows = "nixpkgs";

    nix.url = "github:NixOS/nix";
    nix.inputs.nixpkgs.follows = "nixpkgs";

    hydra.url = "github:t184256/hydra/nix-ca";
    hydra.inputs.nixpkgs.follows = "nixpkgs_21_11";
    nixpkgs_21_11.url = "github:NixOS/nixpkgs/release-21.11";
    hydra.inputs.nix.follows = "nix_2_6";
    nix_2_6.url = "github:NixOS/nix/2.6-maintenance";
    nix_2_6.inputs.nixpkgs.follows = "nixpkgs";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    alacritty-autoresizing = {
      url = "github:t184256/alacritty-autoresizing";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    keyboard-remap = {
      url = "github:t184256/keyboard-remap";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    input-utils = {
      url = "github:t184256/input-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    impermanence,
    simple-nixos-mailserver,
    home-manager,
    nixgl,
    hydra,
    deploy-rs,
    nixos-generators,
    alacritty-autoresizing,
    keyboard-remap,
    input-utils,
    ...
  }@inputs:
  let
    autoimport = (import ./.autoimport);
    specialArgs = { inherit inputs; };
    common_modules = [ impermanence.nixosModule
                       simple-nixos-mailserver.nixosModule
                       home-manager.nixosModules.home-manager {
                         # false as overlays are pulled in where needed
                         home-manager.useGlobalPkgs = false;
                         home-manager.useUserPackages = true;
                         home-manager.extraSpecialArgs = specialArgs;
                     }] ++
                     [ (_: {
                       home-manager.users.monk =
                               autoimport.merge ./user;
                       # disabled as all overlays are user/-side now
                       nixpkgs.overlays = autoimport.asList ./overlays;
                     }) ] ++
                     (autoimport.asPaths ./nixos);
    mkSystem = system: hostcfg:
      nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [ hostcfg ] ++ common_modules;
      };
    nixosConfigurations = {
      lychee = mkSystem "x86_64-linux" ./hosts/lychee/configuration.nix;
      loquat = mkSystem "x86_64-linux" ./hosts/loquat/configuration.nix;
      duckweed = mkSystem "x86_64-linux" ./hosts/duckweed/configuration.nix;
    };
    homeConfigurations.x1c9 = home-manager.lib.homeManagerConfiguration {
      pkgs =  import nixpkgs {
        system = "x86_64-linux";
        overlays = [ nixgl.overlay.x86_64-linux ];
      };
      modules = [ ./hosts/x1c9/home.nix ];
      extraSpecialArgs = { inherit inputs; };
    };
  in
  {
    inherit nixosConfigurations homeConfigurations;
    hydraJobs =
      (builtins.mapAttrs (_: v: v.config.system.build.toplevel)
                         nixosConfigurations)
      // (builtins.mapAttrs (_: v: v.activationPackage) homeConfigurations);

    deploy.nodes.loquat = {
      hostname = "loquat.unboiled.info";
      profiles.system = {
        sshUser = "root"; user = "root"; hostname = "loquat.unboiled.info";
        path = deploy-rs.lib.x86_64-linux.activate.nixos
               self.nixosConfigurations.loquat;
      };
    };
    deploy.nodes.duckweed = {
      hostname = "duckweed.unboiled.info";
      profiles.system = {
        sshUser = "root"; user = "root"; hostname = "duckweed.unboiled.info";
        path = deploy-rs.lib.x86_64-linux.activate.nixos
               self.nixosConfigurations.duckweed;
      };
    };
    checks = builtins.mapAttrs
             (system: deployLib: deployLib.deployChecks self.deploy)
             deploy-rs.lib;

    nixosModules = {
      nixos = autoimport.asAttrs ./nixos;
    };

    packages.x86_64-linux = {
      cookie = nixos-generators.nixosGenerate {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [ ./hosts/cookie/configuration.nix ] ++ common_modules;
        format = "iso";
        inherit specialArgs;
      };
      nixpkgs =  import nixpkgs {
        system = "x86_64-linux";
        overlays = autoimport.asList ./overlays;
      };
    };

  };
}
