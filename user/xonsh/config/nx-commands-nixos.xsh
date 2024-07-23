# TODO: nxg ported to flake workflow
# TODO: combinations

def _nxu():
    ref = __hydra_last_successful_ref()
    $_override = f'github:NixOS/nixpkgs?ref={ref}'
    (cd /etc/nixos && nix flake update --override-input nixpkgs $_override)
    del $_override


def _nxd(args):
    REMOTE_BUILD = {'cocoa', 'loquat'}
    if '--' in args:
        if args.count('--') == 1:  # nxd --deploy-opts -- hosts
            opts, hosts = args[:args.index('--')], args[args.index('--')+1:]
            nix_opts = []
        else: #  nxd --deploy-opts -- hosts --nix-opts
            opts, r = args[:args.index('--')], args[args.index('--')+1:]
            hosts, nix_opts = r[:r.index('--')], r[r.index('--')+1:]
    else:  # nxd hosts
        opts, hosts, nix_opts = [], args, []
    assert not any (h.startswith('-') for h in hosts)
    for host in hosts:
        skip_checks = '--no-skip-checks' not in opts
        remote_build = host in REMOTE_BUILD and '--no-remote-build' not in opts
        opts = [o for o in opts
                if o not in ('--no-skip-checks', '--no-remote-build')]
        cmd = (['deploy'] +
               (['--skip-checks'] if skip_checks else []) +
               (['--remote-build'] if remote_build else []) +
               opts +
               [f'/etc/nixos#{host}'] +
               (['--'] + nix_opts if nix_opts else []))
        echo @(cmd)
        @(cmd)
        del cmd
    del hosts


def _in_tmpdir(cmd):
    def _nxt(extra_args):
        tmp_dir = $(mktemp -d).rstrip()
        $_cmd = cmd
        sudo git config --global --add safe.directory /etc/nixos
        try:
            sh -c @(f'cd {tmp_dir} && $_cmd ' + ' '.join(extra_args))
        finally:
            rm -f @(tmp_dir + '/result')
            rm -d @(tmp_dir)
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
