{ ... }:

let
  IP = {
    duckweed = "51.15.87.8";
    fig = "212.164.221.47";
    loquat = "38.242.239.104";
  };
  zones."unboiled.info".data = ''
    $ORIGIN        unboiled.info.
    $TTL           1800
    @              IN SOA    a.ns.unboiled.info. admin.unboiled.info. (
                                 2022092202; serial number
                                 360       ; refresh
                                 90        ; retry
                                 120960    ; expire
                                 180       ; ttl
                             )
                    MX 10    loquat.unboiled.info.
                    NS       a.ns.unboiled.info.
                    NS       b.ns.unboiled.info.
    a.ns            IN A     ${IP.duckweed}
    b.ns            IN A     ${IP.loquat}

    @               IN A     ${IP.loquat}
    duckweed        IN A     ${IP.duckweed}
    fig             IN A     ${IP.fig}
    loquat          IN A     ${IP.loquat}

    conference.xmpp IN CNAME loquat
    upload.xmpp     IN CNAME loquat
    git             IN CNAME loquat
    natali          IN CNAME fig
    www.natali      IN CNAME fig
    nica            IN CNAME fig
    www.nica        IN CNAME fig
    pasha           IN CNAME fig
    www.pasha       IN CNAME fig
    monk            IN CNAME fig
    www.monk        IN CNAME fig
    transmission    IN CNAME fig
    hydra           IN CNAME loquat
    nix-on-droid    IN CNAME loquat
    yousable        IN CNAME loquat
    lemmy           IN CNAME loquat
    social          IN CNAME loquat
    syncthing-relay IN CNAME duckweed
    meshcentral     IN CNAME duckweed

    _xmpp-client._tcp 86400 IN SRV 5 0 5222 unboiled.info.
    _xmpp-server._tcp 86400 IN SRV 5 0 5269 unboiled.info.

    @               IN TXT   "v=spf1 a:unboiled.info -all"
    _dmarc          IN TXT   "v=DMARC1;p=reject;rua=mailto:postmaster@unboiled.info;ruf=mailto:postmaster@unboiled.info;fo=1"
    _domainkey      IN TXT   "o=-"
    mail._domainkey IN TXT   "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC0Yc6v7MqWEVYJf/SWl+v5+NaggiKUnCD8Zf7gHowlDVrfi0j3miKunSQuct8WJYGSJTMZmWYCvIDv7Axye58Pdj83HqoLxEDzAky0VKyvpgtTpSh4HKJm0uElB1AnHgxOEZEwA1MPiceLohfY+FBI6cYi4j+99JymxWW1eEnqIQIDAQAB"

    _keybase        IN TXT   "keybase-site-verification=7K3IA34hHmhVHl_q-xAreUHNLFHFS1-o6lIjTIu1qPE"
  '';
in
  {
    services.nsd = {
      enable = true;
      interfaces = [ "0.0.0.0" ];
      inherit zones;
    };
    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];
  }
