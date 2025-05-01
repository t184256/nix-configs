{ pkgs, config, ... }:

{
  imports = [ config/no-graphics.nix ];

  programs.password-store.enable = true;
  programs.password-store.package = if config.system.noGraphics
    then pkgs.pass.override { x11Support = false; }
    else pkgs.pass-wayland;

  programs.gpg.enable = true;
  programs.gpg.publicKeys = [ { source = ../misc/pubkeys/pgp; trust = 5; } ];

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    sshKeys = [ "208CCF6C1601D1351502A91D919D98C48CB12B6D" ];
    pinentry.package =
      if config.system.noGraphics
      then pkgs.pinentry-tty
      else pkgs.pinentry-gnome3;
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
