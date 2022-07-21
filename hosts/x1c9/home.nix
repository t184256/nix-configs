{ pkgs, ... }:

{
  home.stateVersion = "22.05";
  home.username = "asosedki";
  home.homeDirectory = "/home/asosedki";
  programs.home-manager.enable = true;
  programs.man.enable = true;

  system.os = "OtherLinux";
  identity.email = "asosedkin@redhat.com";

  imports = [
    ./gnome.nix
    ./keyboard-remap-cz.nix
    ../../user/config/identity.nix
    ../../user/assorted-tools.nix
    ../../user/common.nix
    ../../user/entr.nix
    ../../user/exa.nix
    ../../user/fonts.nix
    ../../user/git.nix
    ../../user/htop.nix
    ../../user/mosh.nix
    ../../user/neovim.nix
    ../../user/terminal.nix
    ../../user/tmux.nix
    ../../user/xdg.nix
    ../../user/xonsh
  ];

  programs.password-store = {enable = true; package = pkgs.pass-wayland; };

  home.packages = with pkgs; [
    nixgl.nixGLIntel
    tiny
  ];
}
