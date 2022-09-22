{ pkgs, config, ... }:

let
  inst = pkgs.writeShellScriptBin "inst" ''
    set -ueo pipefail
    BASEURL=https://raw.githubusercontent.com/t184256/nix-configs/staging
    source <(${pkgs.curl}/bin/curl "$BASEURL/misc/inst/coconut")
  '';
in
{
  system.stateVersion = "22.05";
  nixpkgs.overlays = [];

  home-manager.config =
    { pkgs, ... }:
    {
      system.os = "Nix-on-Droid";
      home.stateVersion = "22.05";
      nixpkgs.overlays = config.nixpkgs.overlays;
      imports = [
        ../../user/config/identity.nix
        ../../user/assorted-tools.nix
        ../../user/common.nix
        ../../user/exa.nix
        ../../user/git.nix
        ../../user/htop.nix
        ../../user/mosh.nix
        ../../user/neovim.nix
      ];

      home.packages = with pkgs; [ inst dash ];
    };
  supervisord.enable = true;
  services.openssh.enable = true;
}
