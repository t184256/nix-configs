{ ... }:

{
  # merely a workaround for a failing `nix flake check` and building on hydra
  # https://github.com/nix-community/home-manager/issues/2074
  manual.manpages.enable = false;
}
