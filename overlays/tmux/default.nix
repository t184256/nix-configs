_: super:

{
  tmux = super.tmux.overrideAttrs (oa: {
    patches = (oa.patches or []) ++ [
      ./altfont.patch
      ./osc52-query-target.patch
    ];
  });
}
