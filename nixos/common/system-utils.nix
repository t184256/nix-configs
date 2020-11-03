{ config, pkgs, lib, ... }: {
  environment.systemPackages = with pkgs; [
    htop ncdu
    vis  # as an emergency text editor
  ];
}
