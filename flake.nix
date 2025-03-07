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
    simple-nixos-mailserver.inputs.nixpkgs-24_11.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.inputs.flake-parts.follows = "flake-parts";

    nixgl.url = "github:guibou/nixGL";
    nixgl.inputs.nixpkgs.follows = "nixpkgs";
    nixgl.inputs.flake-utils.follows = "flake-utils";

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
      url = "github:t184256/yousable";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    autosync-voice = {
      url = "github:t184256/autosync-voice";
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
    deploy-rs,
    nixos-generators,
    alacritty-autoresizing,
    keyboard-remap,
    input-utils,
    yousable,
    autosync-voice,
    ...
  }@inputs:
  let
    nixosHosts = [
      "cocoa" "quince" "sloe" "olosapo" "watermelon" "etrog" "iyokan"  # 2024
      "loquat" "duckweed" "bayroot" "araceae"  # legacy
      "jujube" "lychee"
    ];
    autoimport = (import ./.autoimport);
    specialArgs = { inherit inputs; };
    common_modules = [ impermanence.nixosModule
                       disko.nixosModules.disko
                       simple-nixos-mailserver.nixosModule
                       yousable.nixosModule
                       autosync-voice.nixosModule
                       home-manager.nixosModules.home-manager {
                         # false as overlays are pulled in where needed
                         home-manager.useGlobalPkgs = false;
                         home-manager.useUserPackages = true;
                         home-manager.extraSpecialArgs = specialArgs;
                         home-manager.users.monk.imports = [
                           nixvim.homeManagerModules.nixvim
                           impermanence.nixosModules.home-manager.impermanence
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
    nixosConfigurations = nixpkgs.lib.genAttrs nixosHosts
      (name: mkSystem "x86_64-linux" ./hosts/${name}/configuration.nix);
    homeConfigurations.t14g5 = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ nixgl.overlay ];
      };
      modules = [
        nixvim.homeManagerModules.nixvim
        ./hosts/t14g5/home.nix
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

    deploy.nodes = nixpkgs.lib.genAttrs nixosHosts (name: {
      hostname = name;
      profiles.system = {
        sshUser = "root"; user = "root"; hostname = name;
        path = deploy-rs.lib.x86_64-linux.activate.nixos
               self.nixosConfigurations.${name};
      };
    });

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
          # minimal is fine and preferred
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-base.nix"
          ./hosts/cookie/configuration.nix
        ] ++ common_modules;
        inherit specialArgs;
      }).config.system.build.isoImage;
      nixpkgs = nixpkgs_with_overlays;
    };

  };
}
