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

    services = {
      xserver = {
        enable = true;
        displayManager = {
          gdm = {
            enable = true;
            debug = true;
            wayland = true;
          };
        };
        xkb.layout = "us,ru";
        videoDrivers = [ "modesetting" ];
        desktopManager.gnome.enable = true;
      };
      displayManager.defaultSession = "gnome";
      gnome = {
        gnome-initial-setup.enable = false;
        gnome-remote-desktop.enable = true;
      };
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
        noannoyance-fork
        paperwm
        quake-mode
        sound-output-device-chooser
        unite
      ]);
    };
  };
}
