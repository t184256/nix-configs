
def _w(args):
    """
    Examples:
        w ncdu
        w extra_file.nix ncdu
        w ncdu -- ncdu /
        w - ncdu /
        w py:numpy,notebook -- python -m notebook
    """
    DEFAULT_PACKAGE_SOURCE = 'nixpkgs'

    def expand_arg(arg):  # what to turn a dependency word into?
        if arg.endswith('.nix'):  # a file
            return ['-f', arg]
	# No idea how to attain that using flakes
        #elif arg.startswith('py:'):  # ex: py:numpy,notebook
        #    return ['--expr',
        #            'python3.withPackages (ps: with ps; [ ' +
        #            ' '.join(arg.split(':', 1)[1].split(',')) +
        #            '])']
        #elif arg.startswith('xsh:'):  # ex: xsh:numpy,notebook
        #    return ['--expr',
        #            'xonsh.addExtras (with python3Packages; [ ' +
        #            ' '.join(arg.split(':', 1)[1].split(',')) +
        #            '])']
        elif '#' in arg:  # flake reference
            return [arg]
	else:  # probably a package name
            return [f'{DEFAULT_PACKAGE_SOURCE}#{arg}']

    cmd = []
    if '--' in args:  # run cmd, ex: with ncdu -- ncdu /
        i = args.index('--')
        args, cmd = args[:i], args[i + 1:]
    elif '-' in args:  # pull in following argument, ex: with - ncdu /
        i = args.index('-')
        if args[i + 1] != 'sudo':
            args, cmd = args[:i] + [args[i + 1]], args[i + 1:]
        else:  # 'forgot sudo' scenario: with file - sudo file -s /dev/sdc*
            args, cmd = args[:i] + [args[i + 2]], ['sudo'] + args[i + 2:]
    dir_tail = $(pwd).strip().split('/')[-1]
    features = ['+' + a for a in args] if args else ['@' + dir_tail]
    with_features = ' '.join(features + ${...}.get('WITH_FEATURES', '').split())
    flatten = lambda l: [item for sublist in l for item in sublist]
    args = flatten([expand_arg(a) for a in args])
    with ${...}.swap(WITH_FEATURES=with_features):
        with ${...}.swap(WITH_FEATURES_IMMEDIATE=' '.join(features)):
             nix shell @(args) -c @(cmd if cmd else 'xonsh')

aliases['w'] = _w
del _w

# disabled due to bash completion being broken in general
#
#def _complete_as(line, prefix_used, prefix_instead):
#    import xonsh.completers.bash_completion
#    l = line.replace(prefix_used, prefix_instead, 1)
#    r = xonsh.completers.bash_completion.bash_complete_line(l)
#    return r
#    return {x.replace(prefix_instead, prefix_used, 1).split()[-1] for x in r}
#
#def _with_completer(prefix, line, begidx, endidx, ctx):
#    if not line.startswith('w '):
#        return set()
#    if ' - ' in line or ' -- ' in line:
#        return set()
#    # TODO: completers for py: and xsh:
#    c = (_complete_as(line, 'w ', 'nix shell ') |
#         _complete_as(line, 'w ', f'nix shell {DEFAULT_PACKAGE_SOURCE}#'))
#    return c | {'aaa', 'bbb'}
#
#completer add with _with_completer
#del _with_completer
