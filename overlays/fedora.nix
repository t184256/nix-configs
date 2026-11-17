_: super:

let
  fedoraPackager = "https://src.fedoraproject.org/rpms/fedora-packager/raw";
  fkinitHash = "feff4cf268262addfa37ef61ba98e6556beee813";
  caHash = "a8b86fd62861e21fb07e209d95aeaf28a6ba55eb";
in

{
  fkinit = super.stdenvNoCC.mkDerivation {
    pname = "fkinit";
    version = "feff4cf";
    src = super.fetchurl {
      url = "${fedoraPackager}/${fkinitHash}/f/fkinit";
      hash = "sha256-9MjPDmzqEUtaOeKHEDM5CKuWK/kXzLhtpZxBeqHWHHg=";
    };
    nativeBuildInputs = [ super.makeWrapper ];
    buildInputs = [ super.bash ];
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/bin
      install -m755 $src $out/bin/fkinit
      patchShebangs $out/bin/fkinit
    '';
    postFixup = ''
      wrapProgram $out/bin/fkinit --prefix PATH : "${super.lib.makeBinPath [
        super.coreutils super.krb5 super.systemd
      ]}"
    '';
  };

  fedoraproject-ipa-ca = super.fetchurl {
    url = "${fedoraPackager}/${caHash}/f/" + "fedoraproject_ipa_ca.crt";
    hash = "sha256-ydOCoEdLCdkfqKnTBWuMo1B1qzh2/lWgeqpfD6cSk3o=";
  };
}
