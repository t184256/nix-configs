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

    i18n.inputMethod.enable = true;
    i18n.inputMethod.type = "ibus";  # fcitx5 also has a working Ctrl-Shift-U
    services = {
      xserver = {
        enable = true;
        videoDrivers = [ "modesetting" ];
        desktopManager.gnome.enable = true;
      };
      displayManager = {
        defaultSession = "gnome";
          gdm = {
            enable = true;
            debug = true;
            wayland = true;
          };
      };
      gnome = {
        gnome-initial-setup.enable = false;
        gnome-remote-desktop.enable = true;
      };
    };
    hardware.graphics.enable = true;

    environment = {
      gnome.excludePackages = with pkgs; [
        cheese
        pkgs.gnome-tour
        epiphany
        geary
        pkgs.orca
      ];
      systemPackages = (with pkgs; [
        wl-clipboard
      ]) ++ (with pkgs.gnomeExtensions; [
        auto-activities
        autohide-battery
        autohide-volume
        just-perfection
        open-bar
        paperwm
        sound-output-device-chooser
        unite
      ]);
    };
  };
}
