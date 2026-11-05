{ pkgs, ... }:

let
  mkCveWrapper = env: pkgs.writeShellScriptBin "cve-${env}" ''
    export CVE_USER=monk@unboiled.info
    export CVE_ORG=gnutls
    export CVE_ENVIRONMENT=${env}
    ENTRY=services/mitre/gnutls/monk@unboiled.info/${env}
    export CVE_API_KEY="$(pass show $ENTRY)"
    exec ${pkgs.cve}/bin/cve "$@"
  '';
in
{
  home.packages = [
    pkgs.cve
    (mkCveWrapper "test")
    (mkCveWrapper "prod")
  ];
}
