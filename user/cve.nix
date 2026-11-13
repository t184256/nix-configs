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
  nixpkgs.overlays = [ (import ../overlays/vulnogram.nix) ];

  home.packages = with pkgs; [
    cve
    (mkCveWrapper "test")
    (mkCveWrapper "prod")
    vulnogram
  ];
}
