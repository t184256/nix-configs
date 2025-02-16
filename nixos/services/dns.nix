{ config, ... }:

let
  IP4 = {
    duckweed = "51.15.87.8";
    fig = "212.164.221.47";
    etrog = "152.70.59.201";
    iyokan = "152.70.58.224";
    loquat = "38.242.239.104";
    olosapo = "216.181.107.104";
    sloe = "77.237.232.57";
    watermelon = "104.152.210.200";
  };
  IP6 = {
    araceae = "2001:bc8:710:9839:dc00:ff:fe81:6e69";
    bayroot = "2001:bc8:1d90:124:dc00:ff:fe1d:d261";
    etrog = "2603:c022:c004:2424:355a:eee5:3e59:8866";
    iyokan = "2603:c022:c004:2424:38fd:cc4e:5757:6d9";
    loquat = "2a02:c206:2101:9233::1";
    sloe = "2a02:c206:2207:3890::1";
    olosapo = "2606:a8c0:3:969::a";
    watermelon = "2602:ffd5:1:1b0::1";
  };
  zones."unboiled.info".data = ''
    $ORIGIN        unboiled.info.
    $TTL           1800
    @              IN SOA    a.ns.unboiled.info. admin.unboiled.info. (
                                 2025021001; serial number
                                 360       ; refresh
                                 90        ; retry
                                 120960    ; expire
                                 180       ; ttl
                             )
                    MX 10    loquat.unboiled.info.
                    NS       a.ns.unboiled.info.
                    NS       b.ns.unboiled.info.
                    NS       c.ns.unboiled.info.
    a.ns            IN A     ${IP4.duckweed}
    b.ns            IN A     ${IP4.sloe}
    b.ns            IN AAAA  ${IP6.sloe}
    c.ns            IN A     ${IP4.watermelon}
    c.ns            IN AAAA  ${IP6.watermelon}

    @               IN A     ${IP4.loquat}
    duckweed        IN A     ${IP4.duckweed}
    fig             IN A     ${IP4.fig}
    loquat          IN A     ${IP4.loquat}
    loquat          IN AAAA  ${IP6.loquat}
    sloe            IN A     ${IP4.sloe}
    sloe            IN AAAA  ${IP6.sloe}
    olosapo         IN A     ${IP4.olosapo}
    olosapo         IN AAAA  ${IP6.olosapo}
    watermelon      IN A     ${IP4.watermelon}
    watermelon      IN AAAA  ${IP6.watermelon}
    araceae         IN AAAA  ${IP6.araceae}
    bayroot         IN AAAA  ${IP6.bayroot}
    etrog           IN A     ${IP4.etrog}
    etrog           IN AAAA  ${IP6.etrog}
    iyokan          IN A     ${IP4.iyokan}
    iyokan          IN AAAA  ${IP6.iyokan}

    conference.xmpp IN CNAME loquat
    upload.xmpp     IN CNAME loquat
    git             IN CNAME sloe
    natali          IN CNAME fig
    www.natali      IN CNAME fig
    nica            IN CNAME fig
    www.nica        IN CNAME fig
    pasha           IN CNAME fig
    www.pasha       IN CNAME fig
    monk            IN CNAME loquat
    www.monk        IN CNAME loquat
    transmission    IN CNAME fig
    tabby           IN CNAME fig
    nix-on-droid    IN CNAME loquat
    yousable        IN CNAME watermelon
    lemmy           IN CNAME loquat
    social          IN CNAME loquat
    syncthing-relay IN CNAME duckweed
    meshcentral     IN CNAME duckweed
    ipfs            IN CNAME duckweed

    _xmpp-client._tcp 86400 IN SRV 5 0 5222 unboiled.info.
    _xmpp-server._tcp 86400 IN SRV 5 0 5269 unboiled.info.

    @               IN TXT   "v=spf1 a:unboiled.info -all"
    _dmarc          IN TXT   "v=DMARC1;p=reject;rua=mailto:postmaster@unboiled.info;ruf=mailto:postmaster@unboiled.info;fo=1"
    _domainkey      IN TXT   "o=-"
    mail._domainkey IN TXT   "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC0Yc6v7MqWEVYJf/SWl+v5+NaggiKUnCD8Zf7gHowlDVrfi0j3miKunSQuct8WJYGSJTMZmWYCvIDv7Axye58Pdj83HqoLxEDzAky0VKyvpgtTpSh4HKJm0uElB1AnHgxOEZEwA1MPiceLohfY+FBI6cYi4j+99JymxWW1eEnqIQIDAQAB"

    _keybase        IN TXT   "keybase-site-verification=7K3IA34hHmhVHl_q-xAreUHNLFHFS1-o6lIjTIu1qPE"

    dyn             IN NS    ns1.dynv6.com.
    dyn             IN NS    ns2.dynv6.com.
    dyn             IN NS    ns3.dynv6.com.
    dyn4            IN NS    ns1.dynv6.com.
    dyn4            IN NS    ns2.dynv6.com.
    dyn4            IN NS    ns3.dynv6.com.
    dyn6            IN NS    ns1.dynv6.com.
    dyn6            IN NS    ns2.dynv6.com.
    dyn6            IN NS    ns3.dynv6.com.
  '';
in
  {
    services.nsd = {
      enable = true;
      interfaces =
        if builtins.elem
          config.networking.hostName
          [ "duckweed" "watermelon" "sloe" ]
        then [ "0.0.0.0" "::" ]
        else [ "127.0.0.1" ];
      inherit zones;
      ipFreebind = true;
      ipTransparent = true;
    };
    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];
  }
