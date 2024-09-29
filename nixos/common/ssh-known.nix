{ config, ... }:

let
  keys = builtins.fromTOML (builtins.readFile ../../misc/pubkeys/sshd.toml);
  makeHost = host: key: {
    # TODO: automatic DNS aliases
    extraHostNames = [
      "${host}.unboiled.info"
      "${host}.dyn.unboiled.info"
      "${host}.dyn4.unboiled.info"
      "${host}.dyn6.unboiled.info"
    ] ++ (if host == config.networking.hostName then [] else [ "localhost" ])
      ++ (if host == "sloe" then [] else [ "git.unboiled.info" ]);
    publicKey = key;
  };
  knownHosts = builtins.mapAttrs makeHost keys;
in
{
  programs.ssh.knownHosts = knownHosts;
  programs.ssh.knownHostsFiles = [ ../../misc/pubkeys/github ];
}
