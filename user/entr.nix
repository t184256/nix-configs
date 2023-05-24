{ pkgs, config, ... }:

{
  home.packages = [
    pkgs.entr

    (pkgs.writeShellScriptBin "wat" ''
      exec ${pkgs.findutils}/bin/find ''${*%''${!#}} \
      | grep -v '/__pycache__' \
      | grep -v '\.pyc$' \
      | ${pkgs.entr}/bin/entr -rcs "''${@:$#}"
    '')

    (pkgs.writeShellScriptBin "watpy" ''
      exec wat * "python -m pytest $* -k 'not pylama' && \
                  python -m pytest $* -k pylama"
    '')
  ];
}
