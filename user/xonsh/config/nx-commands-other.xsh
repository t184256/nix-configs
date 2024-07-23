def _nxu():
    ref = __hydra_last_successful_ref()
    $_tgt = f'github:NixOS/nixpkgs?ref={ref}'
    (cd ~/.nix-configs && nix flake update --override-input nixpkgs $_tgt)
    del $_tgt


def _nxs():
    import os
    flake = os.path.expanduser('~/.nix-configs')
    hostname = $HOSTNAME
    nix build @(f'{flake}#homeConfigurations.{hostname}.activationPackage') \
        --out-link /tmp/h-m && /tmp/h-m/activate


aliases['nxu'] = _nxu
aliases['nxs'] = _nxs

del _nxu
del _nxs
