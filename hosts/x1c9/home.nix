{ pkgs, ... }:

{
  home.stateVersion = "22.05";
  home.username = "asosedki";
  home.homeDirectory = "/home/asosedki";
  programs.home-manager.enable = true;
  programs.man.enable = true;

  identity.email = "asosedkin@redhat.com";

  imports = [
    ../../user/config/identity.nix
    ../../user/entr.nix
    ../../user/exa.nix
    ../../user/git.nix
    ../../user/htop.nix
    ../../user/mosh.nix
    ../../user/neovim.nix
    ../../user/terminal.nix
    ../../user/tmux.nix
    ../../user/xonsh
  ];

  home.packages = with pkgs; [
    ripgrep fd
  ];
}
