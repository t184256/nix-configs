{ config, pkgs, lib, ... }: {
  environment.systemPackages = with pkgs; [
    htop ncdu
  ];
}
