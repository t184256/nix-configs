_: prev:

{
  vimPlugins = prev.vimPlugins.extend (
    (prev.callPackage ./generated.nix {})
  );
}
