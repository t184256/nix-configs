{ config, lib, ... }:

let
  forwardPorts = config.networking.nat.forwardPorts;
  # TODO: reflection?
  # TODO: IPv6?
  # TODO: proper ruleMaker
  ruleMaker =
    { proto, sourcePort ? "unused", destination, loopbackIPs ? "unused" }:
    assert lib.strings.hasInfix ":" destination;
    let dest = lib.strings.splitString ":" destination; in
    assert builtins.length dest == 2;
    let
      address = builtins.head dest;
      portRangeDashed = builtins.head (builtins.tail dest);
      portRange =  # worst case is 1-2/3 -> 1:2
        if lib.strings.hasInfix "-" portRangeDashed
        then
          let fromTo = lib.strings.splitString "-" portRangeDashed; in
          assert builtins.length fromTo == 2;
          let
            from = builtins.head fromTo;
            to' = builtins.head (builtins.tail fromTo);
            to =
              if lib.strings.hasInfix "/" to'
              then builtins.head (lib.strings.split "/" to')
              else to';
          in "${from}:${to}"
        else portRangeDashed;
    in
    "-m ${proto} -p ${proto} -d ${address} --dport ${portRange} -j MASQUERADE";
  ruleA = f: "iptables -t nat -A POSTROUTING " + (ruleMaker f);
  ruleD = f: "iptables -t nat -D POSTROUTING " + (ruleMaker f) + " || true";
  join = lib.strings.concatStringsSep "\n";
in
assert
  map ruleA [
    { proto = "tcp"; sourcePort = 1; destination = "2.3.4.5:6"; loopbackIPs=7; }
    { proto = "udp"; sourcePort = "7-8"; destination = "2.3.4.5:9-10/7"; }
  ] == [
    ("iptables -t nat -A POSTROUTING " +
     "-m tcp -p tcp -d 2.3.4.5 --dport 6 -j MASQUERADE")
    ("iptables -t nat -A POSTROUTING " +
     "-m udp -p udp -d 2.3.4.5 --dport 9:10 -j MASQUERADE")
  ];
{
  options.networking.nat.coolerForwardPorts = lib.mkOption {
    default = false;
    type = lib.types.bool;
  };

  # see github.com/NixOS/NixOS/issues/28721
  config.networking.firewall = {
    extraCommands = join (map ruleA config.networking.nat.forwardPorts);
    extraStopCommands = join (map ruleD config.networking.nat.forwardPorts);
  };
}
