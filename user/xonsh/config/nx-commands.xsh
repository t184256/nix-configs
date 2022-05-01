# TODO: nxg ported to flake workflow
# TODO: combinations

def _nxu():
    pushd -q /etc/nixos
    try:
        HYDRA = 'https://hydra.unboiled.info'
        URL = HYDRA + '/jobset/t184256-nix-configs/main-autoupdate/latest-eval'
        ref = $(curl -sL @(URL)
                | grep -E r'nixos-system-.*\.[0-9a-f]{7}'
                | head -n1
                | sed -E r's/.*nixos-system-.*\.([0-9a-f]{7}).*/\1/').rstrip()
        assert len(ref) == 7
        print(f'autodetected nixpkgs commit from {HYDRA}: {ref}')
        override = f'github:NixOS/nixpkgs?ref={ref}'
        nix flake update --override-input nixpkgs @(override)
    finally:
        popd -q


def _nxd(hosts):
    pushd -q /etc/nixos
    try:
        for host in hosts:
            echo deploy --skip-checks @(f'.#{host}')
            deploy --skip-checks @(f'.#{host}')
    finally:
        popd -q


def _in_tmpdir(*cmd):
    def _nxt(extra_args):
        TMP_DIR = $(mktemp -d).rstrip()
        pushd -q @(TMP_DIR)
        try:
            @(cmd + tuple(extra_args))
        finally:
            rm -f result
            popd -q
            rm -d @(TMP_DIR)
    return _nxt


aliases['nxu'] = _nxu
aliases['nxd'] = _nxd
aliases['nxb'] = _in_tmpdir('nixos-rebuild', 'build')
aliases['nxt'] = _in_tmpdir('sudo', 'nixos-rebuild', 'test')
aliases['nxf'] = _in_tmpdir('sudo', 'nixos-rebuild', 'test', '--fast')
aliases['nxs'] = _in_tmpdir('sudo', 'nixos-rebuild', 'switch')
aliases['nxe'] = _in_tmpdir('sh', '-c',
                            'find /etc/nixos | '
                            'entr -rc env time -f "%Ew %Uu %Ss %PCPU" '
                            '         nixos-rebuild --no-build-nix build')

del _nxu
del _nxd
del _in_tmpdir
