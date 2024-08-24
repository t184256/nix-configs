{
  description = "t184256's personal configuration files";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";

    # for unification purposes only
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-compat.url = "github:edolstra/flake-compat";
    gitignore.url = "github:hercules-ci/gitignore.nix";
    gitignore.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.inputs.nixpkgs-stable.follows = "nixpkgs";
    git-hooks.inputs.flake-compat.follows = "flake-compat";
    git-hooks.inputs.gitignore.follows = "gitignore";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit-hooks.inputs.flake-compat.follows = "flake-compat";
    pre-commit-hooks.inputs.gitignore.follows = "gitignore";
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    nmd.url = "sourcehut:~rycee/nmd";
    nmd.inputs.nixpkgs.follows = "nixpkgs";
    nix-formatter-pack.url = "github:Gerschtli/nix-formatter-pack";
    nix-formatter-pack.inputs.nixpkgs.follows = "nixpkgs";
    nix-formatter-pack.inputs.nmd.follows = "nmd";

    nix-on-droid.url = "github:t184256/nix-on-droid/testing";
    nix-on-droid.inputs.nixpkgs.follows = "nixpkgs";
    nix-on-droid.inputs.home-manager.follows = "home-manager";
    nix-on-droid.inputs.nmd.follows = "nmd";
    nix-on-droid.inputs.nix-formatter-pack.follows = "nix-formatter-pack";

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    impermanence.url = "github:nix-community/impermanence";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    simple-nixos-mailserver.url =
      "gitlab:simple-nixos-mailserver/nixos-mailserver";
    simple-nixos-mailserver.inputs.flake-compat.follows = "flake-compat";
    simple-nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs";
    simple-nixos-mailserver.inputs.nixpkgs-24_05.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.inputs.home-manager.follows = "home-manager";
    nixvim.inputs.flake-parts.follows = "flake-parts";
    nixvim.inputs.flake-compat.follows = "flake-compat";
    nixvim.inputs.git-hooks.follows = "git-hooks";
    nixvim.inputs.devshell.follows = "devshell";

    nixgl.url = "github:guibou/nixGL";
    nixgl.inputs.nixpkgs.follows = "nixpkgs";
    nixgl.inputs.flake-utils.follows = "flake-utils";

    hydra.url = "github:thufschmitt/hydra/nix-ca";
    hydra-nix = {
      url = "github:NixOS/nix/2.22-maintenance";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.flake-compat.follows = "flake-compat";
      inputs.pre-commit-hooks.follows = "pre-commit-hooks";
    };
    #hydra.inputs.nixpkgs.follows = "nixpkgs";  # breaks
    hydra.inputs.nix.follows = "hydra-nix";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.inputs.utils.follows = "flake-utils";
    deploy-rs.inputs.flake-compat.follows = "flake-compat";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

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
    yousable = {
      url = "github:t184256/yousable/throttling-rewrite";
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
    disko,
    simple-nixos-mailserver,
    home-manager,
    nixvim,
    nixgl,
    hydra,
    deploy-rs,
    nixos-generators,
    alacritty-autoresizing,
    keyboard-remap,
    input-utils,
    yousable,
    ...
  }@inputs:
  let
    autoimport = (import ./.autoimport);
    specialArgs = { inherit inputs; };
    common_modules = [ impermanence.nixosModule
                       disko.nixosModules.disko
                       simple-nixos-mailserver.nixosModule
                       yousable.nixosModule
                       home-manager.nixosModules.home-manager {
                         # false as overlays are pulled in where needed
                         home-manager.useGlobalPkgs = false;
                         home-manager.useUserPackages = true;
                         home-manager.extraSpecialArgs = specialArgs;
                         home-manager.users.monk.imports = [
                           nixvim.homeManagerModules.nixvim
                         ];
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
      cocoa = mkSystem "x86_64-linux" ./hosts/cocoa/configuration.nix;
      loquat = mkSystem "x86_64-linux" ./hosts/loquat/configuration.nix;
      duckweed = mkSystem "x86_64-linux" ./hosts/duckweed/configuration.nix;
      bayroot = mkSystem "x86_64-linux" ./hosts/bayroot/configuration.nix;
      araceae = mkSystem "x86_64-linux" ./hosts/araceae/configuration.nix;
      quince = mkSystem "x86_64-linux" ./hosts/quince/configuration.nix;
      etrog = mkSystem "x86_64-linux" ./hosts/etrog/configuration.nix;
      sloe = mkSystem "x86_64-linux" ./hosts/sloe/configuration.nix;
      olosapo = mkSystem "x86_64-linux" ./hosts/olosapo/configuration.nix;
      watermelon = mkSystem "x86_64-linux" ./hosts/watermelon/configuration.nix;
    };
    homeConfigurations.x1c9 = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ nixgl.overlay ];
      };
      modules = [
        nixvim.homeManagerModules.nixvim
        ./hosts/x1c9/home.nix
      ];
      extraSpecialArgs = { inherit inputs; };
    };
    homeConfigurations.alter = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ nixgl.overlay ];
      };
      modules = [
        nixvim.homeManagerModules.nixvim
        ./hosts/alter/home.nix
      ];
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
    deploy.nodes.cocoa = {
      hostname = "cocoa";
      profiles.system = {
        sshUser = "root"; user = "root"; hostname = "cocoa";
        path = deploy-rs.lib.x86_64-linux.activate.nixos
               self.nixosConfigurations.cocoa;
      };
    };
    deploy.nodes.bayroot = {
      hostname = "bayroot";
      profiles.system = {
        sshUser = "root"; user = "root"; hostname = "bayroot";
        path = deploy-rs.lib.x86_64-linux.activate.nixos
               self.nixosConfigurations.bayroot;
      };
    };
    deploy.nodes.araceae = {
      hostname = "araceae";
      profiles.system = {
        sshUser = "root"; user = "root"; hostname = "araceae";
        path = deploy-rs.lib.x86_64-linux.activate.nixos
               self.nixosConfigurations.araceae;
      };
    };
    deploy.nodes.quince = {
      hostname = "quince";
      profiles.system = {
        sshUser = "root"; user = "root"; hostname = "quince";
        path = deploy-rs.lib.x86_64-linux.activate.nixos
               self.nixosConfigurations.quince;
      };
    };
    deploy.nodes.etrog = {
      hostname = "etrog";
      profiles.system = {
        sshUser = "root"; user = "root"; hostname = "etrog";
        path = deploy-rs.lib.x86_64-linux.activate.nixos
               self.nixosConfigurations.etrog;
      };
    };
    deploy.nodes.sloe = {
      hostname = "sloe";
      profiles.system = {
        sshUser = "root"; user = "root"; hostname = "sloe";
        path = deploy-rs.lib.x86_64-linux.activate.nixos
               self.nixosConfigurations.sloe;
      };
    };
    deploy.nodes.olosapo = {
      hostname = "olosapo";
      profiles.system = {
        sshUser = "root"; user = "root"; hostname = "olosapo";
        path = deploy-rs.lib.x86_64-linux.activate.nixos
               self.nixosConfigurations.olosapo;
      };
    };
    deploy.nodes.watermelon = {
      hostname = "watermelon";
      profiles.system = {
        sshUser = "root"; user = "root"; hostname = "watermelon";
        path = deploy-rs.lib.x86_64-linux.activate.nixos
               self.nixosConfigurations.watermelon;
      };
    };
    checks = builtins.mapAttrs
             (system: deployLib: deployLib.deployChecks self.deploy)
             deploy-rs.lib;

    nixosModules = {
      nixos = autoimport.asAttrs ./nixos;
    };

    packages.x86_64-linux = {
      cookie = (nixpkgs.lib.nixosSystem {
        #pkgs = import nixpkgs {};
        pkgs = import nixpkgs { system = "x86_64-linux"; };
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ./hosts/cookie/configuration.nix
        ] ++ common_modules;
        inherit specialArgs;
      }).config.system.build.isoImage;
      nixpkgs = nixpkgs_with_overlays;
    };

  };
}
