# TODO: nxg / nxu ported to flake workflow
# TODO: combinations

def _nxt_maker(*extra_args):
    def _nxt(args):
        TMP_DIR = $(mktemp -d).rstrip()
        pushd -q @(TMP_DIR)
	try:
		sudo nixos-rebuild test @(extra_args)
	finally:
		rm -f result
		popd -q
		rm -d @(TMP_DIR)
    return _nxt

aliases['nxt'] = _nxt_maker()
aliases['nxf'] = _nxt_maker('--fast')
aliases['nxs'] = ['sudo', 'nixos-rebuild', 'switch']

del _nxt_maker
