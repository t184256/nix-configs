_: super:

{
  tmux = super.tmux.overrideAttrs (_: { patches = ./altfont.patch; });
}
