# TODO: nxg ported to flake workflow
# TODO: combinations

def _nxu():
    ref = __hydra_last_successful_ref()
    $_override = f'github:NixOS/nixpkgs?ref={ref}'
    (cd /etc/nixos && nix flake update --override-input nixpkgs $_override)
    del $_override


def _nxd(args):
    host, *args = args
    tgt = f'/etc/nixos#nixosConfigurations.{host}.config.system.build.toplevel'
    nom build --no-link @(tgt) && \
        deploy --skip-checks @(f'/etc/nixos#{host}') @(args)


def _nxb(args):
    host = $HOSTNAME
    tgt = f'/etc/nixos#nixosConfigurations.{host}.config.system.build.toplevel'
    nom build --no-link @(tgt)


def _in_tmpdir(cmd):
    def _nxt(extra_args):
        $_TMP_DIR = $(mktemp -d).rstrip()
        $_cmd = cmd + ' '.join(extra_args)
        sudo git config --global --add safe.directory /etc/nixos
        try:
            sh -c f'cd {$_TMP_DIR} && $_cmd'
        finally:
            rm -f @($_TMP_DIR + '/result')
            rm -d $_TMP_DIR
            del $_TMP_DIR
            del $_cmd
    return _nxt


aliases['nxu'] = _nxu
aliases['nxd'] = _nxd
aliases['nxb'] = _nxb
aliases['nxt'] = _in_tmpdir('sudo nixos-rebuild test')
aliases['nxf'] = _in_tmpdir('sudo nixos-rebuild test --fast')
aliases['nxs'] = _in_tmpdir('sudo nixos-rebuild switch')
aliases['nxw'] = _in_tmpdir('find /etc/nixos | '
                            'entr -rc env time -f "%Ew %Uu %Ss %PCPU" '
                            '         nixos-rebuild --no-build-nix build')

del _nxu
del _nxd
del _in_tmpdir
