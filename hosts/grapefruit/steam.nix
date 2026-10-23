{ pkgs, lib, ... }:

{
  programs.steam = {
    enable = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "steam"
    "steam-unwrapped"
  ];
  programs.xwayland.enable = true;

  environment.persistence."/mnt/persist".users.monk.directories = [
    ".steam"
    ".local/share/Steam"
    ".games"
  ];
}
