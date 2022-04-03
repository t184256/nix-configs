{ ... }:

let
  IP = {
    duckweed = "51.158.183.199";
    fig = "212.164.221.47";
    loquat = "38.242.251.25";
    mango = "51.15.87.8";
  };
  zones."unboiled.info".data = ''
    $ORIGIN        unboiled.info.
    $TTL           1800
    @              IN SOA    ns1.unboiled.info. admin.unboiled.info. (
                                 2022040101; serial number
                                 3600      ; refresh
                                 900       ; retry
                                 1209600   ; expire
                                 1800      ; ttl
                             )
                    MX 10    mango.unboiled.info.
                    NS       a.ns.unboiled.info.
                    NS       b.ns.unboiled.info.
    a.ns            IN A     ${IP.duckweed}
    b.ns            IN A     ${IP.loquat}

    @               IN A     ${IP.mango}
    duckweed        IN A     ${IP.duckweed}
    fig             IN A     ${IP.fig}
    loquat          IN A     ${IP.loquat}
    mango           IN A     ${IP.mango}

    git             IN CNAME mango
    edit            IN CNAME mango
    natali          IN CNAME fig
    www.natali      IN CNAME fig
    nica            IN CNAME fig
    www.nica        IN CNAME fig
    pasha           IN CNAME fig
    www.pasha       IN CNAME fig
    monk            IN CNAME fig
    www.monk        IN CNAME fig
    transmission    IN CNAME fig
    hydra           IN CNAME fig
    nix-cache       IN CNAME fig
    nix-on-droid    IN CNAME mango
    syncthing-relay IN CNAME duckweed

    @               IN TXT   "v=spf1 a:unboiled.info -all"
    _dmarc          IN TXT   "v=DMARC1;p=none;pct=100;rua=mailto:postmaster@unboiled.info"
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