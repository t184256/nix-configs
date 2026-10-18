# pi-hot-compact: background ("hot") compaction + context compiler for pi.
# The npm tarball is plain TypeScript sources with no runtime dependencies;
# pi itself provides `typebox` and `@earendil-works/pi-coding-agent`
# (declared as peerDependencies) to installed packages.
final: prev: {
  pi-hot-compact = prev.stdenv.mkDerivation (finalAttrs: {
    pname = "pi-hot-compact";
    version = "0.3.0";

    src = prev.fetchurl {
      url = "https://registry.npmjs.org/pi-hot-compact/-/pi-hot-compact-${finalAttrs.version}.tgz";
      hash = "sha512-YrXx1HnJNLcYDK6UFaaIVhggEAdWUkxIareZQDy55nva6ohWu/RIofkSJRAaqaO7JivUNkPJRDzDLoymUnEoIg==";
    };

    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/node_modules/${finalAttrs.pname}
      cp -r . $out/lib/node_modules/${finalAttrs.pname}
      runHook postInstall
    '';
  });
}
