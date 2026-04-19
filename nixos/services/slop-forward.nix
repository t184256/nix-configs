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
        proxy_buffering off;
        proxy_request_buffering off;
        client_max_body_size 0;
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
  services.litellm = {
    enable = true;
    host = "127.0.0.1";
    port = 11110;
    settings =
      let
        plum  = "http://192.168.99.53:11111/v1";
        grapefruit = "http://192.168.99.52:11111";
        qwen35Think = {
          temperature = 0.6;
          top_p = 0.95;
          presence_penalty = 1.5;
          extra_body = {
            top_k = 20;
            chat_template_kwargs.enable_thinking = true;
          };
        };
        qwen35Nothink = {
          temperature = 0.7;
          top_p = 0.8;
          presence_penalty = 1.5;
          extra_body = {
            top_k = 20;
            chat_template_kwargs.enable_thinking = false;
          };
        };
        qwen36Think = qwen35Think;
        qwen36Nothink = qwen35Nothink;
        # hosts: primary first, fallbacks after
        models = {
          "qwen3.5-35b-a3b".hosts = [ plum grapefruit ];
          "qwen3.6-35b-a3b".hosts = [ grapefruit ];
          "qwen3.5-27b".hosts = [ plum grapefruit ];

          "qwen3.5-0.8b".hosts = [ grapefruit ];
          "qwen3.5-122b-a10b".hosts = [ grapefruit ];

          "sweep-v2-7b".hosts = [ grapefruit ];
          "sweep-1.5b".hosts = [ grapefruit ];
          "sweep-0.5b".hosts = [ grapefruit ];
        };
        aliases = {
          "qwen3.5-0.8b-think" =
            { model = "qwen3.5-0.8b"; params = qwen35Think; };
          "qwen3.5-0.8b-nothink" =
            { model = "qwen3.5-0.8b"; params = qwen35Nothink; };
          "qwen3.5-27b-think" =
            { model = "qwen3.5-27b"; params = qwen35Think; };
          "qwen3.5-27b-nothink" =
            { model = "qwen3.5-27b"; params = qwen35Nothink; };
          "qwen3.6-35b-a3b-think" =
            { model = "qwen3.6-35b-a3b"; params = qwen36Think; };
          "qwen3.6-35b-a3b-nothink" =
            { model = "qwen3.6-35b-a3b"; params = qwen36Nothink; };
          "qwen3.5-35b-a3b-think" =
            { model = "qwen3.5-35b-a3b"; params = qwen35Think; };
          "qwen3.5-35b-a3b-nothink" =
            { model = "qwen3.5-35b-a3b"; params = qwen35Nothink; };
          "qwen3.5-122b-a10b-think" =
            { model = "qwen3.5-122b-a10b"; params = qwen35Think; };
          "qwen3.5-122b-a10b-nothink" =
            { model = "qwen3.5-122b-a10b"; params = qwen35Nothink; };

          sweep.model = "sweep-v2-7b";
          sweep-v2-7b.model = "sweep-v2-7b";
          "sweep-1.5b".model = "sweep-1.5b";
          "sweep-0.5b".model = "sweep-0.5b";
        };
        grapefruitCatchall = {
          model_name = "*";
          litellm_params = {
            model = "custom_openai/*";
            api_base = grapefruit;
            api_key = "dummy";
          };
        };
        mkModel = clientName: api_base: backendName: extra: {
          model_name = clientName;
          litellm_params = {
            model = "custom_openai/${backendName}";
            inherit api_base;
            api_key = "dummy";
          } // extra;
        };
        mkEntries = clientName: { model, params ? {} }:
          let inherit (models.${model}) hosts; in
            [ (mkModel clientName (builtins.head hosts) model params) ]
            ++ map
              (h: mkModel "fb-${clientName}" h model params)
              (builtins.tail hosts);
        mkFallback = clientName: { model, ... }:
          if builtins.length models.${model}.hosts < 2 then []
          else [ { "${clientName}" = [ "fb-${clientName}" ]; } ];
      in {
        model_list = builtins.concatLists (builtins.attrValues
          (builtins.mapAttrs mkEntries aliases))
          ++ [ grapefruitCatchall ];
        litellm_settings.fallbacks = builtins.concatLists (builtins.attrValues
          (builtins.mapAttrs mkFallback aliases));
      };
  };

  services.nginx = {
    virtualHosts = {
      "llm.slop.unboiled.info" =
        mkForward "http://127.0.0.1:11110";
      "whisper.slop.unboiled.info" =
        mkForward "http://192.168.99.52:11112";
      "goose.slop.unboiled.info" =
        mkForward "http://192.168.99.52:8000";
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
