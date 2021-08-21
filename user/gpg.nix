{ pkgs, config, ... }:

{
  imports = [ config/no-graphics.nix ];

  programs.password-store.enable = true;

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    sshKeys = [ "208CCF6C1601D1351502A91D919D98C48CB12B6D" ];
    pinentryFlavor = if config.system.noGraphics then "tty" else "gnome3";
  };

  # hacky hack: https://releases.nixos.org/nix-dev/2016-June/020831.html
  xdg.configFile = if config.system.noGraphics then {} else {
    "autostart/gnome-keyring-ssh.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=SSH Agent
      Comment=GNOME Keyring: SSH Agent
      Exec=/usr/bin/env true
      Hidden=true
    '';
  };
}
