_: super:

let
  ibusPatched = super.ibus.overrideAttrs (oa: {
    patches = (oa.patches or []) ++ [ ./quieter-hex-pretext.patch ];
  });
in
{
  inherit ibusPatched;
  # dirty hack:
  # * keep pkgs.ibus unpatched, so that packages link against the cached one,
  # * but make pkgs.ibus-with-plugins use our patched ibus, and
  # * use the (internal) i18n.inputMethod.package = ibusPatched; (desktop.nix),
  #   just in case
  ibus-with-plugins = super.ibus-with-plugins.override { ibus = ibusPatched; };
}
