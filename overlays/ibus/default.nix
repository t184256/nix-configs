_: super:

{
  ibus = super.ibus.overrideAttrs ( oa: {
    patches = (oa.patches or []) ++ [ ./quieter-hex-pretext.patch ];
  });
}
