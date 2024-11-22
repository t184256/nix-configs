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
    ./email.nix
    ./keyboard-remap-cz.nix
    ../../user/config/identity.nix
    ../../user/config/language-support.nix
    ../../user/assorted-tools.nix
    ../../user/common.nix
    ../../user/du.nix
    ../../user/entr.nix
    ../../user/eza.nix
    ../../user/fonts.nix
    ../../user/git.nix
    ../../user/htop.nix
    ../../user/mosh.nix
    ../../user/neovim
    ../../user/terminal.nix
    ../../user/tmux.nix
    ../../user/xdg.nix
    ../../user/xonsh
  ];

  programs.password-store = {enable = true; package = pkgs.pass-wayland; };

  neovim.fat = true;
  language-support = [
    "bash"
    "c"
    "markdown"
    "nix"
    "prose"
    "python"
    "rust"
    "yaml"
  ];

  home.packages = with pkgs; [
    bash-completion
    nixgl.nixGLIntel
    tiny
    wl-clipboard
    git-absorb
    sccache
    btdu
  ];
}
