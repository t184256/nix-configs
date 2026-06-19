{ pkgs, lib, ... }:

let
  # TODO: persist signing key, pin thp and rotate only {0,1,2}.jwk with ECMR
  keysDir = "/var/lib/tangd";  # ephemeral, assuming tmpfs by default

  rotate = pkgs.writeShellScript "tang-rotate" ''
    set -eEuo pipefail
    if [ -f "${keysDir}/exc.jwk" ]; then
      mv "${keysDir}/exc.jwk" "${keysDir}/exc-prev.jwk"
    fi
    if [ -f "${keysDir}/sig.jwk" ]; then
      mv "${keysDir}/sig.jwk" "${keysDir}/sig-prev.jwk"
    fi
    ${pkgs.jose}/bin/jose jwk gen -i '{"alg":"ES512"}' > "${keysDir}/sig.jwk"
    ${pkgs.jose}/bin/jose jwk gen -i '{"alg":"ECMR"}' > "${keysDir}/exc.jwk"
    chmod 600 "${keysDir}"/*.jwk
  '';
in

{
  services.tang = {
    enable = true;
    listenStream = [ "192.168.98.4:1449" ];
    ipAddressAllow = [ "any" ];
  };
  networking.firewall.allowedTCPPorts = [ 1449 ];

  users = {
    users.tangd = { isSystemUser = true; group = "tangd"; };
    groups.tangd = {};
  };
  systemd.services."tangd@".serviceConfig.DynamicUser = lib.mkForce false;

  systemd = {
    # don't listen until the first rotation has run.
    sockets.tangd = {
      requires = [ "tang-rotate.service" ];
      after    = [ "tang-rotate.service" ];
      wantedBy = lib.mkForce [ "multi-user.target" ];
    };

    services.tang-rotate = {
      serviceConfig = {
        Type = "oneshot";
        ExecStart = rotate;
        User = "tangd";
        Group = "tangd";
        StateDirectory = "tangd";
      };
    };

    timers.tang-rotate = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "0";  # immediately at boot
        OnUnitActiveSec = "5min";  # and every 5 minutes
      };
    };
  };
}
