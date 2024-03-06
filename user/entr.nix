{ pkgs, config, ... }:

{
  home.packages = [
    pkgs.entr

    (pkgs.writeShellScriptBin "wat" ''
      exec ${pkgs.findutils}/bin/find ''${*%''${!#}} \
      | grep -vF '/cassettes/' \
      | grep -vE '(__pycache__/|\.pyc)$' \
      | grep -vE '^(./|)htmlcov/' \
      | ${pkgs.entr}/bin/entr -rcs "''${@:$#}"
    '')

    (pkgs.writeShellScriptBin "watpy" ''
      exec wat * "ruff check .; \
                  python -m pytest --ff --no-cov-on-fail \
                                   --cov-report term-missing:skip-covered \
                                   --durations=3 --durations-min=.05 \
                                   --tb=short \
                                   --no-header \
                                   $* && \
                  ruff check . && \
                  ruff format --check . && \
                  echo ok"
    '')
  ];
}
