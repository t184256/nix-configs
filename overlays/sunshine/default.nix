_: super:

{
  sunshine = super.sunshine.overrideAttrs ( oa: {
    patches = (oa.patches or []) ++ [ ./unicode-input.patch ];
  });
}
