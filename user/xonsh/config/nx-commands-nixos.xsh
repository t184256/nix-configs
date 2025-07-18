# TODO: nxg ported to flake workflow
# TODO: combinations


def _nx_config_dir():
    import os
    home_path = os.path.expanduser('~/.nix-configs')
    for path in (home_path, '/etc/nixos'):
        if os.path.exists(os.path.join(path, 'flake.nix')):
            return path
    raise RuntimeError(f'neither /etc/nixos nor {home_path} were found')


def _nxd(args):
    REMOTE_BUILD = {'cocoa', 'loquat'}
    confdir = _nx_config_dir()
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
               [f'{confdir}#{host}'] +
               (['--'] + nix_opts if nix_opts else []))
        echo @(cmd)
        @(cmd)
        del cmd
    del hosts


def _in_tmpdir(cmd):
    def _nxt(extra_args):
        tmp_dir = $(mktemp -d).rstrip()
        confdir = _nx_config_dir()
        $_cmd = cmd.replace('%FLAKE%', confdir)
        if confdir == '/etc/nixos':
            sudo git config --global --add safe.directory /etc/nixos
        nix flake archive --flake @(confdir) --option warn-dirty false
        try:
            sh -c @(f'cd {tmp_dir} && $_cmd ' + ' '.join(extra_args))
        finally:
            rm -f @(tmp_dir + '/result')
            rm -d @(tmp_dir)
            del $_cmd
    return _nxt


aliases['nxd'] = _nxd
aliases['nxu'] = _in_tmpdir('nix flake update --flake %FLAKE && '
                            'nix flake archive --flake %FLAKE%')
aliases['nxb'] = _in_tmpdir('nixos-rebuild build --flake %FLAKE%')
aliases['nxt'] = _in_tmpdir('sudo nixos-rebuild test --flake %FLAKE%')
aliases['nxf'] = _in_tmpdir('sudo nixos-rebuild test --fast --flake %FLAKE%')
aliases['nxs'] = _in_tmpdir('sudo nixos-rebuild switch --flake %FLAKE%')
aliases['nxe'] = _in_tmpdir('find %FLAKE% | '
                            'entr -rc env time -f "%Ew %Uu %Ss %PCPU" '
                            '         nixos-rebuild --no-build-nix build'
                            '                       --flake %FLAKE%')

del _nxd
del _in_tmpdir
