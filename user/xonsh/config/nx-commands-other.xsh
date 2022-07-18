def _nxu():
    ref = __hydra_last_successful_ref()
    $_tgt = f'github:NixOS/nixpkgs?ref={ref}'
    (cd ~/home/.nix-configs && nix flake update --override-input nixpkgs $_tgt)
    del $_tgt


def _nxs():
    nix build @(f'.#homeConfigurations.{$HOSTNAME}.activationPackage') \
        --out-link /tmp/h-m
    /tmp/h-m/activate


aliases['nxu'] = _nxu
aliases['nxs'] = _nxs

del _nxu
del _nxs
