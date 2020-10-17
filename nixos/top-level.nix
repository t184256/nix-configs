{ config, pkgs, lib, ... }: {
  environment.systemPackages = with pkgs; [
    ltrace strace
  ];
}
