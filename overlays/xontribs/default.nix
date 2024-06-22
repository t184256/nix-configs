_: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (
      _: python-prev:
        prev.lib.attrsets.mapAttrs'
          (n: prev.lib.attrsets.nameValuePair ("xontrib-" + n))
          (builtins.mapAttrs (_: f: (f {
                                        pkgs = prev;
                                        python3Packages = python-prev;
                                      }))
                             ((import ../../.autoimport).asAttrs ./.))
    )
  ];
}
