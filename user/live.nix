{ lib, config, pkgs, ... }:

let
  live-network = pkgs.writeShellScriptBin "live-network" ''
    set -uexo pipefail
    [[ -e /dev/disk/by-partlabel/VTOYEFI ]]
    if [[ -e /run/media/monk/VTOYEFI/secrets.7z.gpg ]]; then
      cp -rv /run/media/monk/VTOYEFI/secrets.7z.gpg /tmp/
    else
      mkdir /tmp/VTOYEFI
      sudo mount -o ro /dev/disk/by-partlabel/VTOYEFI /tmp/VTOYEFI
      cp -rv /tmp/VTOYEFI/secrets.7z.gpg /tmp/
      sudo umount /tmp/VTOYEFI
      rm -d /tmp/VTOYEFI
    fi

    ${pkgs.gnupg}/bin/gpg -d /tmp/secrets.7z.gpg > /tmp/secrets.7z
    pushd /tmp
      ${pkgs.p7zip}/bin/7z x /tmp/secrets.7z
    popd
    sudo cp -r /tmp/secrets/*.nmconnection \
               /etc/NetworkManager/system-connections/
    sudo chown -R root:root /etc/NetworkManager/system-connections
    sudo chmod -R 600 /etc/NetworkManager/system-connections
    sudo chmod 700 /etc/NetworkManager/system-connections
    sudo systemctl restart NetworkManager
    if [[ -e /tmp/secrets/rhca.pem ]] && [[ -e /tmp/secrets/rhvpn.ovpn ]]; then
      sudo cp /tmp/secrets/rhca.pem /etc/pki/tls/certs/2015-RH-IT-Root-CA.pem
      sudo chown root:root /etc/pki/tls/certs/2015-RH-IT-Root-CA.pem
      sudo chmod 640 /etc/pki/tls/certs/2015-RH-IT-Root-CA.pem
      sudo cp /tmp/secrets/rhvpn.ovpn \
        /etc/NetworkManager/system-connections/rhvpn.ovpn
      sudo chown root:root /etc/NetworkManager/system-connections/rhvpn.ovpn
      sudo chmod 600 /etc/NetworkManager/system-connections/rhvpn.ovpn
    fi
    rm -r /tmp/secrets.7z
    rm -r /tmp/secrets
    touch /tmp/.network-configured

    ${pkgs.networkmanager}/bin/nm-online
  '';
  live = pkgs.writeShellScriptBin "live" ''
    set -uexo pipefail
    ${pkgs.systemd}/bin/systemctl start keyboard-remap
    ${live-network}/bin/live-network
  '';
  inst = pkgs.writeShellScriptBin "inst" ''
    set -ueo pipefail
    touch /tmp/.inst
    chmod 700 /tmp/.inst
    BASEURL=https://raw.githubusercontent.com/t184256/nix-configs/staging
    ${pkgs.curl}/bin/curl "$BASEURL/misc/inst/auto" > /tmp/.inst
    exec /tmp/.inst
  '';
in
{
  imports = [ ./config/no-graphics.nix ./config/live.nix ];

  xdg.dataFile = lib.mkIf (! config.system.noGraphics && config.system.live) {
    "applications/live.desktop".text = ''
      [Desktop Entry]
      Categories=System;
      Exec=${live}/bin/live
      GenericName=Configure live system
      Icon=networkmanager
      Name=Configure live system
      Terminal=true
      Type=Application
    '';
    "applications/inst.desktop".text = ''
      [Desktop Entry]
      Categories=System;
      Exec=${inst}/bin/inst
      GenericName=Reinstall a system
      Icon=system-software-install
      Name=Reinstall a system
      Terminal=true
      Type=Application
    '';
  };

  home.packages = lib.mkIf config.system.live [ live-network live inst ];
}
