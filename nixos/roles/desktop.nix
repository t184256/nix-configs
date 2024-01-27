{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.system.role.desktop;
in {
  options = {
    system.role.desktop.enable = mkOption {
      default = false;
      example = true;
      description = ''
        Enable what t184256 prefers as a desktop these days.
      '';
      type = types.bool;
    };
  };

  config = mkIf cfg.enable {
    programs.dconf.enable = true;  # for h-m's dconf.settings

    services.xserver = {
      enable = true;
      displayManager.gdm.enable = true;
      displayManager.gdm.debug = true;
      displayManager.gdm.wayland = true;
      displayManager.defaultSession = "gnome";
      desktopManager.gnome.enable = true;
      layout = "us,ru";
      videoDrivers = [ "modesetting" ];
    };
    hardware.opengl.enable = true;

    environment = {
      gnome.excludePackages = with pkgs.gnome; [
        cheese
        pkgs.gnome-tour
        epiphany
        geary
        pkgs.orca
      ];
      systemPackages = (with pkgs; [
        wl-clipboard
      ]) ++ (with pkgs.gnomeExtensions; [
        allow-locked-remote-desktop
        autohide-battery
        autohide-volume
        just-perfection
        noannoyance-2
        paperwm
        quake-mode
        sound-output-device-chooser
        syncthing-indicator
        unite
      ]);
    };

    services.gnome.gnome-initial-setup.enable = false;
    services.gnome.gnome-remote-desktop.enable = true;
  };
}
