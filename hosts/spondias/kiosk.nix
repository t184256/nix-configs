{ pkgs, lib, ... }:

let
  display-fifo = pkgs.writeShellScript "display-fifo" ''
    while true; do cat /run/kiosk; done
  '';
in
{
  system.noGraphics = lib.mkForce false;
  hardware.graphics.enable = true;

  services.usbguard = {
    enable = true;
    rules = "reject";
    implicitPolicyTarget = "block";
    presentDevicePolicy = "reject";
    insertedDevicePolicy = "block";
  };

  users = {
    users.kiosk = {
      isNormalUser = true;
      home = "/home/kiosk";
      createHome = true;
      group = "kiosk";
    };
    users.monk.extraGroups = [ "kiosk" ];
    groups.kiosk = {};
  };

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    xwayland.enable = false;
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.sway}/bin/sway";
      user = "kiosk";
    };
  };

  home-manager.users.kiosk = {
    imports = [
      ../../user/fonts.nix
      ../../user/terminal.nix
    ];
    home.stateVersion = "25.11";

    system.noGraphics = false;
    wayland.windowManager.sway = {
      enable = true;
      config = {
        modifier = "Mod4";
        bars = [ ];
        window.border = 0;
        gaps = { inner = 0; outer = 0; };
        output."*".transform = "270";
        output."*".dpms = "on";
        startup = [
          {
            command =
              "term --option window.startup_mode=Fullscreen -e ${display-fifo}";
          }
        ];
        keybindings = { };
      };
      extraConfig = ''
        for_window [app_id="Alacritty"] fullscreen enable
      '';
    };

  };

  systemd.tmpfiles.rules = [ "p /run/kiosk 0660 kiosk kiosk -" ];
}
