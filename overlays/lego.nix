final: prev:
# Doesn't work with non-default python version

let
  newerVer = "4.29.0";
  overrides-fresh = _: {
    name = "lego-${newerVer}";
    version = newerVer;
    src = prev.fetchFromGitHub {
      owner = "go-acme";
      repo = "lego";
      rev = "v${newerVer}";
      hash = "sha256-czCOrgC3Xy42KigAe+tsPRdWqxgdHFl0KN3Ei2zeyy8=";
    };
    vendorHash = "sha256-OnCtobizqDrqZTQenRPBTlUHvNx/xX34PYw8K4rgxSk=";
  };
  lego = if prev.lib.versionAtLeast prev.lego.version newerVer
    then prev.lego
    else prev.lego.overrideAttrs overrides-fresh;
in
{
  inherit lego;
}
