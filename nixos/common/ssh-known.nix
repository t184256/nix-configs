{ config, ... }:

let
  keys = builtins.fromTOML (builtins.readFile ../../misc/pubkeys/sshd.toml);
  makeHost = host: key: {
    # TODO: automatic DNS aliases
    # TODO: nebula names or IPs
    extraHostNames = [
      "${host}.unboiled.info"
      "${host}.dyn.unboiled.info"
      "${host}.dyn4.unboiled.info"
      "${host}.dyn6.unboiled.info"
    ] ++ (if host == config.networking.hostName then [ "localhost" ] else [])
      ++ (if host == "sloe" then [ "git.unboiled.info" ] else []);
    publicKey = key;
  };
  knownHosts = builtins.mapAttrs makeHost keys;
in
{
  programs.ssh.knownHosts = knownHosts;
  programs.ssh.knownHostsFiles = [ ../../misc/pubkeys/github ];
}
