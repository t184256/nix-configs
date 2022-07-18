def __hydra_last_successful_ref():
    HYDRA = 'https://hydra.unboiled.info'
    URL = HYDRA + '/jobset/t184256-nix-configs/main-autoupdate/latest-eval'
    ref = $(curl -sL @(URL)
            | grep -E r'nixos-system-.*\.[0-9a-f]{7}'
            | head -n1
            | sed -E r's/.*nixos-system-.*\.([0-9a-f]{7}).*/\1/').rstrip()
    assert len(ref) == 7
    print(f'autodetected nixpkgs commit from {HYDRA}: {ref}')
    return ref
