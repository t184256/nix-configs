
_: super:

{
  akkoma =
    if super.lib.versionAtLeast super.akkoma.version "3.13.2"
      then super.akkoma
      else super.akkoma.overrideAttrs (_: rec {
        version = "3.13.2";
        src = super.fetchFromGitea {
          domain = "akkoma.dev";
          owner = "AkkomaGang";
          repo = "akkoma";
          rev = "v${version}";
          hash = "sha256-WZAkpJIPzAbqXawNiM3JqE9tJzxrNs/2dGAWVMwLpN4=";
        };
      });
}
