{ pkgs, ... }:

{
  programs.ssh.extraConfig = ''
    Host eu.nixbuild.net
      PubkeyAcceptedKeyTypes ssh-ed25519
      IdentityFile /tmp/.nixbuild.key
  '';

  programs.ssh.knownHosts = {
    nixbuild = {
      hostNames = [ "eu.nixbuild.net" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
    };
  };

  # I don't do that because I opt-in with command-line switches
  #nix = {
  #  distributedBuilds = true;
  #  buildMachines = [
  #    { hostName = "eu.nixbuild.net";
  #      system = "x86_64-linux";
  #      maxJobs = 100;
  #      supportedFeatures = [ "benchmark" "big-parallel" ];
  #    }
  #  ];
  #};

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "nixbuild-unlock-key" ''
      set -uexo pipefail
      if [[ $# -ge 1 ]]; then
          [[ $1 == 'control' ]] && FROM=t184256 || FROM=t184256-$1
      else
         FROM=t184256-$(hostname)
      fi
      KEY=/tmp/.nixbuild.key
      [[ ! -e $KEY ]]
      touch $KEY
      sudo chown root:root $KEY
      sudo chmod 600 $KEY
      pass show services/nixbuild.net/$FROM | tail -n+3 | sudo tee $KEY \
          >/dev/null
    '')
    (pkgs.writeShellScriptBin "nixbuild-lock-key" ''
      set -ueo pipefail
      KEY=/tmp/.nixbuild.key
      sudo rm -f $KEY
      [[ ! -e $KEY ]]
    '')
  ];
}
