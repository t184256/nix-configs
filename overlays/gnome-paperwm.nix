# Pin newer PaperWM until EGO gets an approved GNOME 51 version.
# https://github.com/paperwm/PaperWM/releases/tag/v51.0.0
final: prev:
let
  uuid = "paperwm@paperwm.github.com";
in
{
  gnomeExtensions = prev.lib.recurseIntoAttrs (prev.gnomeExtensions // {
    paperwm = prev.stdenvNoCC.mkDerivation (finalAttrs: {
      pname = "gnome-shell-extension-paperwm";
      version = "51.0.0";

      src = final.fetchFromGitHub {
        owner = "paperwm";
        repo = "PaperWM";
        tag = "v${finalAttrs.version}";
        hash = "sha256-m01roFOC/iGHWlKer6X/Qn+MWDl6NJ1YG0KPz3IiqH4=";
      };

      nativeBuildInputs = [ final.buildPackages.glib ];

      buildPhase = ''
        runHook preBuild
        glib-compile-schemas --strict schemas
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/gnome-shell/extensions
        cp -r --no-preserve=mode . $out/share/gnome-shell/extensions/${uuid}
        runHook postInstall
      '';

      passthru = {
        extensionPortalSlug = "paperwm";
        extensionUuid = uuid;
      };
    });
  });
}
