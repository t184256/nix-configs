{ pkgs, ... }:

let
  custom-auth = pkgs.writeText "custom-auth.py" ''
    import os, socket, sys
    from socketserver import ThreadingUnixStreamServer, StreamRequestHandler

    FORBIDDEN = b'HTTP/1.1 403 Forbidden\r\nContent-Length: 14\r\nConnection: close\r\n\r\n403 Forbidden\n'
    OK = b'HTTP/1.1 200 OK\r\nContent-Length: 7\r\nConnection: close\r\n\r\n200 OK\n'
    assert os.environ.get('LISTEN_PID') == str(os.getpid())
    assert os.environ.get('LISTEN_FDS') == '1'
    with open('/mnt/persist/secrets/custom-auth') as f:
        MATCHING_HEADERS = [h.strip() for h in f.readlines() if ':' in h]

    class Handler(StreamRequestHandler):
        def handle(self):
            for l in self.rfile:
                l = l.decode().strip()
                if not l:
                    break
                elif l in MATCHING_HEADERS:
                    #sys.stderr.write('-- pass --\n')
                    self.wfile.write(OK)
                    self.wfile.close()
                    return
                #sys.stderr.write(f'> {l}\n')
            self.wfile.write(FORBIDDEN)
            self.wfile.close()

    class Server(ThreadingUnixStreamServer):
        def __init__(self, server_address, handler_cls):
            ThreadingUnixStreamServer.__init__(
                self, server_address, handler_cls, bind_and_activate=False
            )
            self.socket = socket.fromfd(3, socket.AF_UNIX, socket.SOCK_STREAM)

    if __name__ == "__main__":
        Server(("", 0), Handler).serve_forever()
  '';
  mkForward = address: {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = address;
      extraConfig = ''
        auth_request /custom-auth;
        proxy_read_timeout 1800s;
      '';
    };
    locations."/custom-auth" = {
      proxyPass = "http://unix:/run/custom-auth.sock:/";
      extraConfig = ''
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";
        proxy_set_header X-Original-URI $request_uri;
      '';
    };
  };
in
{
  services.nginx = {
    virtualHosts = {
      "whisper.slop.unboiled.info" = mkForward "http://192.168.99.52:11112";
      "llm.slop.unboiled.info" = mkForward "http://192.168.99.52:11111";
      "goose.slop.unboiled.info" = mkForward "http://192.168.99.52:8000";
    };
  };
  systemd.sockets.custom-auth = {
    wantedBy = [ "sockets.target" ];
    socketConfig.ListenStream = "/run/custom-auth.sock";
    socketConfig.Accept = false;
  };
  systemd.services.custom-auth = {
    wantedBy = [ "multi-user.target" ];
    requires = [ "custom-auth.socket" ];
    serviceConfig.ExecStart = "${pkgs.python3}/bin/python ${custom-auth}";
  };
}
