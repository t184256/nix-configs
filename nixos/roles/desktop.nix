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
    services.xserver = {
      enable = true;
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
      layout = "us,ru";
    };

    environment = {
      gnome.excludePackages = with pkgs.gnome; [
        cheese
        epiphany
        geary
      ];
      systemPackages = (with pkgs; [
        wl-clipboard
      ]) ++ (with pkgs.gnomeExtensions; [
        gsconnect
        allow-locked-remote-desktop
        autohide-battery
        autohide-volume
        focus-changer
        just-perfection
        noannoyance
        quake-mode
        sound-output-device-chooser
        syncthing-indicator
        unite
      ]);
    };

    services.gnome.gnome-initial-setup.enable = false;
    services.gnome.gnome-remote-desktop.enable = true;

    # KDE Connect
    networking.firewall.allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
  };
}
