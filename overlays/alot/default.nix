_: super:

{
  alot =
    (super.alot.override { python311 = super.python312; })
    .overrideAttrs ( oa: {
      patches = (oa.patches or []) ++ [ ./workaround-1647.patch ];
      disabledTests = (oa.disabledTests or []) ++ [
        "tests/test_crypto.py::TestDecrypt::test_decrypt"
      ];
    });
}
