{ pkgs, config, ... }:

let
  inst = pkgs.writeShellScriptBin "inst" ''
    set -ueo pipefail
    BASEURL=https://raw.githubusercontent.com/t184256/nix-configs/staging
    export PATH=${pkgs.curl}/bin:$PATH
    source <(curl "$BASEURL/misc/inst/carambola")
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
        ../../user/eza.nix
        ../../user/git.nix
        ../../user/htop.nix
        ../../user/mosh.nix
        ../../user/neovim.nix
      ];

      home.packages = with pkgs; [ inst ];
    };

  #terminal.font = ("${pkgs.iosevka-t184256}/" +
  #                 "share/fonts/truetype/iosevka-t184256-regular.ttf");
  terminal.font = "${pkgs.iosevka}/share/fonts/truetype/iosevka-regular.ttf";
}
