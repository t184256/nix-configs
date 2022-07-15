_: super:

{
  rpm = super.rpm.overrideAttrs (oa: {
    configureFlags = oa.configureFlags ++ [ "--with-cap" ];
    propagatedBuildInputs = oa.propagatedBuildInputs ++ [ super.libcap ];
  });
}
