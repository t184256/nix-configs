{ ... }:

{
  networking.firewall = {
    allowedTCPPorts = [ 226 229 ];
    allowedUDPPortRanges = [ { from = 22600; to = 22699; } ];
  };
  networking.nat = {
    enable = true;
    externalInterface = "ens2";
    coolerForwardPorts = true;
    forwardPorts = [
      { proto = "tcp"; sourcePort = 226; destination = "192.168.99.6:22"; }
      { proto = "tcp"; sourcePort = 229; destination = "192.168.99.6:2229"; }
      {
        proto = "udp";
        sourcePort = "22600:22699";
        destination = "192.168.99.6:22600-22699/22600";
      }
    ];
  };

  # rate-limit that port per IP because I can't meaningfully sshguard it
  # accept ACCEPTs without DNATing, effectively blackholing
  networking.firewall = {
    extraCommands = ''
      iptables -t nat -I PREROUTING -p tcp --dport 226 -m conntrack --ctstate NEW -m recent --set --name SSH226 -j LOG --log-prefix SSH226-CONNECT-
      iptables -t nat -I PREROUTING -p tcp --dport 226 -m conntrack --ctstate NEW -m recent --rcheck --name SSH226 --seconds 180 --hitcount 7 -j ACCEPT
      iptables -t nat -I PREROUTING -p tcp --dport 229 -m conntrack --ctstate NEW -m recent --set --name SSH229 -j LOG --log-prefix SSH229-CONNECT-
      iptables -t nat -I PREROUTING -p tcp --dport 229 -m conntrack --ctstate NEW -m recent --rcheck --name SSH229 --seconds 180 --hitcount 7 -j ACCEPT
    '';
    extraStopCommands = ''
      iptables -t nat -D PREROUTING -p tcp --dport 226 -m conntrack --ctstate NEW -m recent --rcheck --name SSH226 --seconds 180 --hitcount 7 -j ACCEPT || true
      iptables -t nat -D PREROUTING -p tcp --dport 226 -m conntrack --ctstate NEW -m recent --set --name SSH226 -j LOG --log-prefix SSH226-CONNECT- || true
      iptables -t nat -D PREROUTING -p tcp --dport 229 -m conntrack --ctstate NEW -m recent --rcheck --name SSH229 --seconds 180 --hitcount 7 -j ACCEPT || true
      iptables -t nat -D PREROUTING -p tcp --dport 229 -m conntrack --ctstate NEW -m recent --set --name SSH229 -j LOG --log-prefix SSH229-CONNECT- || true
    '';
  };
}
