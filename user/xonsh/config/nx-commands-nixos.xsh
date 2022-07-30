# TODO: nxg ported to flake workflow
# TODO: combinations

def _nxu():
    ref = __hydra_last_successful_ref()
    $_override = f'github:NixOS/nixpkgs?ref={ref}'
    (cd /etc/nixos && nix flake update --override-input nixpkgs $_override)
    del $_override


def _nxd(hosts):
    for host in hosts:
        $_tgt = f'.#{host}'
        echo deploy --skip-checks $_tgt
        (cd /etc/nixos && deploy --skip-checks $_tgt)
        del $_tgt


def _in_tmpdir(cmd):
    def _nxt(extra_args):
        $_TMP_DIR = $(mktemp -d).rstrip()
        $_cmd = cmd
        sudo git config --global --add safe.directory /etc/nixos
        try:
            sh -c @(f'cd {$_TMP_DIR} && $_cmd' + ' '.join(extra_args))
        finally:
            rm -f @($_TMP_DIR + '/result')
            rm -d $_TMP_DIR
            del $_TMP_DIR
            del $_cmd
    return _nxt


aliases['nxu'] = _nxu
aliases['nxd'] = _nxd
aliases['nxb'] = _in_tmpdir('nixos-rebuild build')
aliases['nxt'] = _in_tmpdir('sudo nixos-rebuild test')
aliases['nxf'] = _in_tmpdir('sudo nixos-rebuild test --fast')
aliases['nxs'] = _in_tmpdir('sudo nixos-rebuild switch')
aliases['nxe'] = _in_tmpdir('find /etc/nixos | '
                            'entr -rc env time -f "%Ew %Uu %Ss %PCPU" '
                            '         nixos-rebuild --no-build-nix build')

del _nxu
del _nxd
del _in_tmpdir
