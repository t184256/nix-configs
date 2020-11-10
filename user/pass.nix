{ pkgs, config, ... }:

{
  imports = [ config/no-graphics.nix ];

  programs.password-store.enable = true;
  services.gpg-agent.enable = true;
  services.gpg-agent.pinentryFlavor = if config.system.noGraphics then "tty" else "gtk2";
}
