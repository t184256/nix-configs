{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.system.role.fedora-packager;
in {
  options = {
    system.role.fedora-packager.enable = mkOption {
      default = false;
      example = true;
      description = "Fedora packaging tools: FAS, fedpkg, ...";
      type = types.bool;
    };
    system.role.fedora-packager.fasUser = mkOption {
      default = "";
      example = "asosedkin";
      description = "FAS account name.";
      type = types.str;
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      security.krb5.enable = true;
      security.krb5.settings = {
        libdefaults = {
          rdns = false;
          dns_lookup_realm = false;
          dns_canonicalize_hostname = false;
        };
        realms."FEDORAPROJECT.ORG" = {
          kdc = "https://id.fedoraproject.org/KdcProxy";
          pkinit_anchors = "FILE:${pkgs.fedoraproject-ipa-ca}";
          auto_fast_armor = true;
        };
        domain_realm = {
          ".fedoraproject.org" = "FEDORAPROJECT.ORG";
          "fedoraproject.org" = "FEDORAPROJECT.ORG";
          ".centos.org" = "FEDORAPROJECT.ORG";
          "centos.org" = "FEDORAPROJECT.ORG";
        };
      };
      environment.systemPackages = [ pkgs.fkinit pkgs.fedpkg ];
    })
    (mkIf (cfg.enable && cfg.fasUser != "") {
      home-manager.users.monk.home.file.".fedora.upn".text =
        cfg.fasUser + "\n";
    })
  ];
}
