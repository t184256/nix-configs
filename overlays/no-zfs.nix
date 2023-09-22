# see installation-cd-minimal-new-kernel-no-zfs.nix in nixpkgs
_: super: {
  zfs = super.zfs.overrideAttrs(_: {
    meta.platforms = [];
  });
}
