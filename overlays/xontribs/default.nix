self: super:

{
  python3 = super.python3.override {
    packageOverrides = pyself: pysuper: (
      super.lib.attrsets.mapAttrs'
        (n: super.lib.attrsets.nameValuePair ("xontrib-" + n))
        (builtins.mapAttrs (_: f: (f { pkgs = super; }))
                           ((import ../../.autoimport).asAttrs ./.))
    );
  };
}
