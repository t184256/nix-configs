_: super:

{
  mosh = super.mosh.overrideAttrs (oa: {
    patches = (oa.patches or []) ++ [ ./altfont.patch ];
  });
}
