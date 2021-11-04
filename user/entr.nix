{ pkgs, config, ... }:

{
  home.packages = [
    pkgs.entr

    (pkgs.writeShellScriptBin "en" ''
      exec find "''${@:2}" | ${pkgs.entr}/bin/entr -rcs "$1"
    '')

    (pkgs.writeShellScriptBin "wat" ''
      exec ${pkgs.findutils}/bin/find ''${*%''${!#}} | \
        ${pkgs.entr}/bin/entr -rcs "''${@:$#}"
    '')
  ];
}
