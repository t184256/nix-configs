# TODO: nxg / nxu ported to flake workflow
# TODO: combinations

def _in_tmpdir(*cmd):
    def _nxt(*extra_args):
        TMP_DIR = $(mktemp -d).rstrip()
        pushd -q @(TMP_DIR)
	try:
		@(cmd + extra_args)
	finally:
		rm -f result
		popd -q
		rm -d @(TMP_DIR)
    return _nxt

aliases['nxb'] = _in_tmpdir('nixos-rebuild', 'build')
aliases['nxt'] = _in_tmpdir('sudo', 'nixos-rebuild', 'test')
aliases['nxf'] = _in_tmpdir('sudo', 'nixos-rebuild', 'test', '--fast')
aliases['nxs'] = _in_tmpdir('sudo', 'nixos-rebuild', 'switch')
aliases['nxe'] = _in_tmpdir('sh', '-c',
 			     'find /etc/nixos | '
			     'entr -rc env time -f "%Ew %Uu %Ss %PCPU" '
			     '         nixos-rebuild --fast build')

del _in_tmpdir
