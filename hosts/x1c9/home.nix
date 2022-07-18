{ pkgs, ... }:

{
  home.stateVersion = "22.05";
  home.username = "asosedki";
  home.homeDirectory = "/home/asosedki";
  programs.home-manager.enable = true;
  programs.man.enable = true;

  #identity.email = "asosedkin@redhat.com";

  home.packages = with pkgs; [
    ripgrep fd
  ];
}
