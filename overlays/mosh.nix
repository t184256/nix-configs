_: super:

{
  # I want truecolor support from 6cfa4aef598146cfbde7f7a4a83438c3769a2835
  mosh = super.mosh.overrideAttrs (_: {
    name = "mosh-1.3.2+";
    src = super.fetchFromGitHub {
      owner = "mobile-shell";
      repo = "mosh";
      rev = "03087e7a761df300c2d8cd6e072890f8e1059dfa";
      sha256 = "170m3q9sxw6nh8fvrf1l0hbx0rjjz5f5lzhd41143kd1rps3liw8";
    };
    patchFlags = [ "-p1" "-t" ];
  });
}
