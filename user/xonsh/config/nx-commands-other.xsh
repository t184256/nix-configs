def _nxs():
    import os
    flake = os.path.expanduser('~/.nix-configs')
    hostname = $HOSTNAME
    nix build @(f'{flake}#homeConfigurations.{hostname}.activationPackage') \
        --out-link /tmp/h-m && /tmp/h-m/activate


aliases['nxs'] = _nxs
aliases['nxu'] = ('nix flake update --flake ~/.nix-configs && '
                  'nix flake archive --flake ~/.nix-configs')

del _nxs
