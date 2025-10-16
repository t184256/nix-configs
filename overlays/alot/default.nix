_: super:

{
  alot =
    super.alot.overrideAttrs ( oa: {
      patches = (oa.patches or []) ++ [ ./workaround-1647.patch ];
      disabledTests = (oa.disabledTests or []) ++ [
        "tests/test_crypto.py::TestDecrypt::test_decrypt"
      ];
    });
}
