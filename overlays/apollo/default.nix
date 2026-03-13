self: super:

{
  apollo = super.sunshine
    .overrideAttrs ( oa: rec {
      pname = "apollo";
      version = "0.4.6";
      src = super.fetchFromGitHub {
        owner = "ClassicOldSong";
        repo = "Apollo";
        tag = "v${version}";
        hash = "sha256-bjQdGo7JttWnrp7Z7BeU20A7y4YqIURtIzC146mr7go=";
        fetchSubmodules = true;
      };
      postPatch = builtins.replaceStrings ["1.87.0"] ["1.88.0"] oa.postPatch;
      ui = super.sunshine.ui.overrideAttrs ( _: rec {
        pname = "apollo-ui";
        inherit src version;
        postPatch = "cp ${./package-lock.json} ./package-lock.json";
        npmDepsHash = "sha256-vuPjiQ7hWNJX6fd4u9y8YjcB2U4Zt0vDclj0E7GbadQ=";
        npmDeps = super.fetchNpmDeps {
          inherit src;
          name = "${pname}-${version}-npm-deps";
          hash = npmDepsHash;
          postPatch = "cp ${./package-lock.json} ./package-lock.json";
        };
      });
      patches = (oa.patches or []) ++ [ ./unicode-input.patch ];
    });
}
