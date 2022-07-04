_: super:

{
  plymouth = super.plymouth.overrideAttrs (oa: {
    postPatch = oa.postPatch + ''
      substituteInPlace themes/bgrt/bgrt.plymouth.desktop --replace \
          'DialogClearsFirmwareBackground=true' \
          'DialogClearsFirmwareBackground=false'
    '';
  });
}
