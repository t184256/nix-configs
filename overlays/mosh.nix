_: super:

{
  # I want truecolor support from 6cfa4aef598146cfbde7f7a4a83438c3769a2835
  mosh = super.mosh.overrideAttrs (oa: {
    name = "mosh-1.3.2+";
    src = super.fetchFromGitHub {
      owner = "mobile-shell";
      repo = "mosh";
      rev = "e023e81c08897c95271b4f4f0726ec165bb6e1bd";
      sha256 = "136967mf51k7x51xd9997zq92gychg2l4q1niyig9zmr4054jv2z";
    };
    patchFlags = [ "-p1" "-t" "--verbose" ];
    patches = (
      super.lib.remove
        (super.fetchpatch {
          url = "https://github.com/mobile-shell/mosh/commit/e5f8a826ef9ff5da4cfce3bb8151f9526ec19db0.patch";
          sha256 = "15518rb0r5w1zn4s6981bf1sz6ins6gpn2saizfzhmr13hw4gmhm";
        })
        oa.patches
    );
    postPatch = ''
      substituteInPlace scripts/mosh.pl \
          --subst-var-by ssh "${super.openssh}/bin/ssh"
      substituteInPlace scripts/mosh.pl \
          --subst-var-by mosh-client "$out/bin/mosh-client"
    '';
  });
}
