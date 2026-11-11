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
        # lower priority than mkDefault = 1000
        videoDrivers = lib.mkOverride 1001 [ "modesetting" ];
      };
      desktopManager.gnome.enable = true;
      displayManager = {
        defaultSession = "gnome";
          gdm = {
            enable = true;
            debug = true;
          };
      };
      gnome = {
        gnome-initial-setup.enable = false;
        gnome-remote-desktop.enable = true;
        gcr-ssh-agent.enable = false;  # prefer gpg-agent
      };
    };
    hardware.graphics.enable = true;

    # Restore monitors.xml from /mnt/persist at boot (impermanence#147)
    systemd.services.monitors-xml = {
      description = "Restore monitors.xml from /mnt/persist";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        src=/mnt/persist/home/monk/.config/monitors.xml
        dst=/home/monk/.config/monitors.xml
        mkdir -p "$(dirname "$dst")"
        cp -n "$src" "$dst" || true
      '';
    };
    # Save it back at shutdown
    systemd.services."monitors-xml-save" = {
      description = "Save monitors.xml to /mnt/persist";
      wantedBy = [ "shutdown.target" ];
      before = [ "umount.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        src=/home/monk/.config/monitors.xml
        dst=/mnt/persist/home/monk/.config/monitors.xml
        [ -e "$src" ] || exit 0
        mkdir -p /mnt/persist/home/monk/.config
        cp -f "$src" "$dst" || true
      '';
    };

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
        unite
      ]);
    };
  };
}
