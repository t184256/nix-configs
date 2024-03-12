{ pkgs, ... }:

let
  testpy = pkgs.writeShellScriptBin "testpy" ''
    set -ue
    ruff check . || true
    COV_OPTS=""
    if grep -q pytest-cov flake.nix 2>/dev/null || \
        grep -q pytest-cov pyproject.toml 2>/dev/null; then
      COV_OPTS="--no-cov-on-fail --cov-report term-missing:skip-covered"
    fi

    python -m pytest $COV_OPTS \
                     --ff \
                     --durations=3 --durations-min=.05 \
                     --tb=short \
                     --no-header \
                     "$@"
    if [ -e .pre-commit-config.yaml ]; then
      pre-commit run -a
    else
      ruff check . && ruff format --check .
    fi
    echo ok
  '';
in
{
  home.packages = [
    pkgs.entr

    (pkgs.writeShellScriptBin "wat" ''
      exec ${pkgs.findutils}/bin/find ''${*%''${!#}} \
      | grep -vF './.git' \
      | grep -vE '(__pycache__|\.pyc)$' \
      | grep -vE '^(./|)\.(mypy|ruff|pytest)_cache/' \
      | grep -vE '^(./|)htmlcov/' \
      | grep -vF '/cassettes/' \
      | ${pkgs.entr}/bin/entr -rcs "''${@:$#}"
    '')

    (pkgs.writeShellScriptBin "watpy" ''
      exec wat . ${testpy}/bin/testpy
    '')
  ];
}
