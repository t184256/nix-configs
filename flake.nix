{
  description = "t184256's personal configuration files";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";

    nix-on-droid.url = "github:t184256/nix-on-droid/testing";
    nix-on-droid.inputs.nixpkgs.follows = "nixpkgs";
    nix-on-droid.inputs.home-manager.follows = "home-manager";

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    impermanence.url = "github:nix-community/impermanence";

    simple-nixos-mailserver.url =
      "gitlab:simple-nixos-mailserver/nixos-mailserver";
    simple-nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs";
    simple-nixos-mailserver.inputs.utils.follows = "flake-utils";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixgl.url = "github:guibou/nixGL";
    nixgl.inputs.nixpkgs.follows = "nixpkgs";
    nixgl.inputs.flake-utils.follows = "flake-utils";

    hydra.url = "github:t184256/hydra/nix-ca-reprise";
    #nix.url = "github:NixOS/nix/2.13-maintenance";
    #hydra.inputs.nix.follows = "nix";
    #hydra.inputs.nixpkgs.follows = "nix/nixpkgs";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.inputs.utils.follows = "flake-utils";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
    nixd.url = "github:nix-community/nixd";
    nixd.inputs.nixpkgs.follows = "nixpkgs";

    alacritty-autoresizing = {
      url = "github:t184256/alacritty-autoresizing";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    keyboard-remap = {
      url = "github:t184256/keyboard-remap";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    input-utils = {
      url = "github:t184256/input-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    podcastify = {
      url = "github:t184256/podcastify";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    yousable = {
      url = "github:t184256/yousable";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

  };

  outputs = {
    self,
    nixpkgs,
    nix-on-droid,
    nixos-hardware,
    impermanence,
    simple-nixos-mailserver,
    home-manager,
    nixgl,
    hydra,
    deploy-rs,
    nixos-generators,
    nixd,
    alacritty-autoresizing,
    keyboard-remap,
    input-utils,
    podcastify,
    yousable,
    ...
  }@inputs:
  let
    autoimport = (import ./.autoimport);
    specialArgs = { inherit inputs; };
    common_modules = [ impermanence.nixosModule
                       simple-nixos-mailserver.nixosModule
                       podcastify.nixosModule
                       yousable.nixosModule
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
      jujube = mkSystem "x86_64-linux" ./hosts/jujube/configuration.nix;
      cashew = mkSystem "x86_64-linux" ./hosts/cashew/configuration.nix;
      loquat = mkSystem "x86_64-linux" ./hosts/loquat/configuration.nix;
      duckweed = mkSystem "x86_64-linux" ./hosts/duckweed/configuration.nix;
    };
    homeConfigurations.x1c9 = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ nixgl.overlay ];
      };
      modules = [ ./hosts/x1c9/home.nix ];
      extraSpecialArgs = { inherit inputs; };
    };
    nixOnDroidConfigurations = {
      coconut = nix-on-droid.lib.nixOnDroidConfiguration {
        config = ./hosts/coconut/nix-on-droid.nix;
        system = "aarch64-linux";
      };
      carambola = nix-on-droid.lib.nixOnDroidConfiguration {
        config = ./hosts/carambola/nix-on-droid.nix;
        pkgs = import nixpkgs {
          system = "aarch64-linux";
          overlays = autoimport.asList ./overlays;
        };
        system = "aarch64-linux";
      };
    };
    nixpkgs_with_overlays = import nixpkgs {
      system = "x86_64-linux";
      overlays = autoimport.asList ./overlays;
    };
  in
  {
    inherit nixosConfigurations homeConfigurations nixOnDroidConfigurations;
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
    deploy.nodes.cashew = {
      hostname = "cashew";
      profiles.system = {
        sshUser = "root"; user = "root"; hostname = "cashew";
        path = deploy-rs.lib.x86_64-linux.activate.nixos
               self.nixosConfigurations.cashew;
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
        pkgs = nixpkgs_with_overlays;
        modules = [ ./hosts/cookie/configuration.nix ] ++ common_modules;
        format = "iso";
        inherit specialArgs;
      };
      nixpkgs = nixpkgs_with_overlays;
    };

  };
}
