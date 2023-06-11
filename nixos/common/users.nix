{ pkgs, ... }:

{
  users.users.monk = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" ];
  };

  # a hack to `loginctl enable-linger monk`
  # https://github.com/NixOS/nixpkgs/issues/3702
  system.activationScripts.loginctl-enable-linger-monk =
    pkgs.lib.stringAfter [ "users" ] ''
      ${pkgs.systemd}/bin/loginctl enable-linger monk
    '';
}
