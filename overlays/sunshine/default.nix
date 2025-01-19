_: super:

{
  sunshine = (super.sunshine.override {
    # remove after https://github.com/NixOS/nixpkgs/issues/375131
    boost = super.pkgs.boost186;
  }).overrideAttrs ( oa: {
    patches = (oa.patches or []) ++ [ ./unicode-input.patch ];
  });
}
