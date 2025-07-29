def _nxs():
    import os
    flake = os.path.expanduser('~/.nix-configs')
    hostname = $HOSTNAME
    nix flake archive @(flake) --option warn-dirty false
    nix build @(f'{flake}#homeConfigurations.{hostname}.activationPackage') \
        --out-link /tmp/h-m && /tmp/h-m/activate


aliases['nxs'] = _nxs
aliases['nxu'] = ('nix flake update --flake ~/.nix-configs && '
                  'nix flake archive ~/.nix-configs')

del _nxs
