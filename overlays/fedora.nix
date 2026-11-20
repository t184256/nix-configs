_: super:

let
  fedoraPackager = "https://src.fedoraproject.org/rpms/fedora-packager/raw";
  fkinitHash = "feff4cf268262addfa37ef61ba98e6556beee813";
  caHash = "a8b86fd62861e21fb07e209d95aeaf28a6ba55eb";
  p3 = super.python3Packages;

  rpmautospec-core = p3.buildPythonPackage (finalAttrs: {
    pname = "rpmautospec-core";
    version = "0.3.0";
    pyproject = true;
    src = super.fetchurl {
      url = "https://files.pythonhosted.org/packages/41/5f/9d02069851f9fadeff6a1658ecf80b878c238544a15aabea71c911f9d4b6/rpmautospec_core-0.3.0.tar.gz";
      hash = "sha256-4MuRmlI9Dtq9RFVT9v2+tvR06uCZrg42KY3s82kFqJM=";
    };
    build-system = [ p3.hatchling ];
    pythonImportsCheck = [ "rpmautospec_core" ];
    meta = {
      description = "Core functionality for rpmautospec";
      homepage = "https://github.com/fedora-infra/rpmautospec-core";
      license = super.lib.licenses.mit;
    };
  });

  rpmautospec = p3.buildPythonPackage (finalAttrs: {
    pname = "rpmautospec";
    version = "0.8.5";
    pyproject = true;
    src = super.fetchurl {
      url = "https://files.pythonhosted.org/packages/c9/40/8114fbe1cd1d697fa4e6566a1a8915b27f1612a9a579efbd2530ced524c9/rpmautospec-0.8.5.tar.gz";
      hash = "sha256-4fM+n4gQs7KXf0SV8SNlCa1dRWcR01GshEkVOJxksl4=";
    };
    build-system = [ p3.hatchling ];
    # rpm for the real spec parser (minirpm fallback otherwise),
    # libgit2 for the bundled minigit2 git wrapper,
    # click for the CLI entry point
    buildInputs = [ super.libgit2 ];
    dependencies = [ rpmautospec-core p3.click super.rpm super.libgit2 ];
    # the minigit2 wrapper dlopens libgit2 by name, so it needs a loader path
    env.LD_LIBRARY_PATH = "${super.libgit2}/lib";
    makeWrapperArgs = [ "--prefix" "LD_LIBRARY_PATH" ":" "${super.libgit2}/lib" ];
    pythonImportsCheck = [ "rpmautospec" ];
    # ship the %autorelease/%autochangelog macros for plain rpmbuild use;
    # rpkg processes dist-git specs itself and doesn't need them
    postInstall = ''
      install -Dm644 $(find /build -name macros.rpmautospec -path '*rpm_macros.d*') \
        $out/etc/rpm/macros.d/macros.rpmautospec
    '';
    meta = {
      description = "A package and CLI tool to generate RPM release fields and changelogs";
      homepage = "https://github.com/fedora-infra/rpmautospec";
      license = super.lib.licenses.gpl2Only; # MIT AND GPL-2.0-only WITH GCC-exception-2.0 AND (MIT OR GPL-2.0-or-later WITH GCC-exception-2.0)
      mainProgram = "rpmautospec";
    };
  });
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

  # rpkg (and thus fedpkg) needs rpmautospec in its python environment to
  # process %autorelease/%autochangelog dist-git specs locally
  python3Packages = p3 // {
    inherit rpmautospec rpmautospec-core;
    rpkg = p3.rpkg.overrideAttrs (old: {
      propagatedBuildInputs = old.propagatedBuildInputs ++ [ rpmautospec ];
      # rpmautospec's minigit2 wrapper dlopens libgit2 by name at import time
      makeWrapperArgs = [ "--prefix" "LD_LIBRARY_PATH" ":" "${super.libgit2}/lib" ];
    });
  };
}
