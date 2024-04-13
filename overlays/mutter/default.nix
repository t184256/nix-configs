_: super:

{
  gnome = super.gnome // {
    mutter = super.gnome.mutter.overrideAttrs ( oa: {
      patches = (oa.patches or []) ++ [ ./stop-ignoring-vkms.patch ];
    });
  };
}
