{ ... }:

{
  networking.firewall = {
    allowedTCPPorts = [ 227 ];
    allowedUDPPortRanges = [ { from = 22700; to = 22799; } ];
  };
  networking.nat = {
    enable = true;
    externalInterface = "ens2";
    coolerForwardPorts = true;
    forwardPorts = [
      { proto = "tcp"; sourcePort = 227; destination = "192.168.99.7:22"; }
      {
        proto = "udp";
        sourcePort = "22700:22799";
        destination = "192.168.99.7:22700-22799/22700";
      }
    ];
  };

  # rate-limit that port per IP because I can't meaningfully sshguard it
  # accept ACCEPTs without DNATing, effectively blackholing
  networking.firewall = {
    extraCommands = ''
      iptables -t nat -I PREROUTING -p tcp --dport 227 -m conntrack --ctstate NEW -m recent --set --name SSH227 -j LOG --log-prefix SSH227-CONNECT-
      iptables -t nat -I PREROUTING -p tcp --dport 227 -m conntrack --ctstate NEW -m recent --rcheck --name SSH227 --seconds 180 --hitcount 7 -j ACCEPT
    '';
    extraStopCommands = ''
      iptables -t nat -D PREROUTING -p tcp --dport 227 -m conntrack --ctstate NEW -m recent --rcheck --name SSH227 --seconds 180 --hitcount 7 -j ACCEPT || true
      iptables -t nat -D PREROUTING -p tcp --dport 227 -m conntrack --ctstate NEW -m recent --set --name SSH227 -j LOG --log-prefix SSH227-CONNECT- || true
    '';
  };
}
