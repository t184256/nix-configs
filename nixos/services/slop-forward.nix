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
  mkForward = address: extraLocation: extraLocations: {
    enableACME = true;
    forceSSL = true;
    locations = {
      "/" = {
        proxyPass = address;
        extraConfig = ''
          auth_request /custom-auth;
          proxy_read_timeout 1800s;
          proxy_buffering off;
          proxy_request_buffering off;
          client_max_body_size 0;
        '';
      } // extraLocation;
    } // extraLocations // {
      "/custom-auth" = {
        proxyPass = "http://unix:/run/custom-auth.sock:/";
        extraConfig = ''
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
          proxy_set_header X-Original-URI $request_uri;
        '';
      };
    };
  };
in
{
  services.litellm = {
    enable = true;
    host = "127.0.0.1";
    port = 11110;
    #environment.LITELLM_LOG = "DEBUG";
    settings =
      let
        plum = "http://192.168.99.53:11111/v1";
        plumMini = "http://192.168.99.53:11113/v1";
        grapefruit = "http://192.168.99.52:11111/v1";
        grapefruitMini = "http://192.168.99.52:11113/v1";
        cocoa = "http://192.168.99.7:11113/v1";
        qwen38Think = {
          temperature = 0.6;
          top_p = 0.95;
          presence_penalty = 1.5;
          extra_body = {
            top_k = 20;
            chat_template_kwargs.enable_thinking = true;
            chat_template_kwargs.preserve_thinking = true;
          };
        };
        qwen38Nothink = {
          temperature = 0.7;
          top_p = 0.8;
          presence_penalty = 1.5;
          extra_body = {
            top_k = 20;
            chat_template_kwargs.enable_thinking = false;
          };
        };
        # hosts: primary first, fallbacks after
        models = {
          "qwen3.8-flash-next".hosts = [ grapefruit ];
          "qwen3.8-27b".hosts = [ plum ];
          "LFM2.5-8B-A2B".hosts = [ grapefruitMini ];
          "d1-3B".hosts = [ cocoa ];
        };
        aliases = {
          "interactive" = { model = "qwen3.8-27b"; params = qwen38Think; };
          "batch" = { model = "qwen3.8-flash-next"; params = qwen38Think; };
          "mini".model = "LFM2.5-8B-A2B";

          "default" = { model = "qwen3.8-flash-next"; params = qwen38Think; };
          "default-think" =
            { model = "qwen3.8-flash-next"; params = qwen38Think; };
          "default-nothink" =
            { model = "qwen3.8-flash-next"; params = qwen38Nothink; };

          "qwen3.8-27b-think" =
            { model = "qwen3.8-27b"; params = qwen38Think; };
          "qwen3.8-27b-nothink" =
            { model = "qwen3.8-27b"; params = qwen38Nothink; };
          "qwen3.8-flash-next-think" =
            { model = "qwen3.8-flash-next"; params = qwen38Think; };
          "qwen3.8-flash-next-nothink" =
            { model = "qwen3.8-flash-next"; params = qwen38Nothink; };

          # decisions go to /v1/systemone, bypassing litellm
          "decision".model = "d1-3B";
        };
        mkModel = clientName: api_base: backendName: extra: {
          model_name = clientName;
          litellm_params = {
            model = "custom_openai/${backendName}";
            inherit api_base;
            api_key = "dummy";
            extra_body =
              { thinking_budget_tokens = 16384; }
              // (extra.extra_body or {});
          } // (builtins.removeAttrs extra [ "extra_body" ]);
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
          (builtins.mapAttrs mkEntries aliases));
        litellm_settings = {
          fallbacks = builtins.concatLists (builtins.attrValues
            (builtins.mapAttrs mkFallback aliases));
          default_model_settings = {
            extra_body = { thinking_budget_tokens = 16384; };
          };
        };
      };
  };

  services.nginx = {
    virtualHosts = {
      # /v1/systemone skips litellm (old version only speaks chat completions)
      "llm.slop.unboiled.info" =
        mkForward "http://127.0.0.1:11110" {} {
          "/v1/systemone" = {
            proxyPass = "http://192.168.99.7:11113";
            extraConfig = ''
              auth_request /custom-auth;
              proxy_read_timeout 600s;
              proxy_buffering off;
              client_max_body_size 0;
            '';
          };
        };
      "whisper.slop.unboiled.info" =
        mkForward "http://192.168.99.7:11112" {} {};
      "goose.slop.unboiled.info" =
        mkForward "http://192.168.99.52:8000" {} {};
      "ctl.slop.unboiled.info" =
        mkForward "http://192.168.99.53:9988" {} {};
      # `Authorization: Bearer ...` / `Sec-WebSocket-Key`
      "paseo.slop.unboiled.info" =  # belt and suspenders, my auth + header auth
        let
          proxied = { proxyPass = "http://192.168.99.53:6767"; };
        in
          mkForward "http://192.168.99.53:6767" { proxyWebsockets = true; } {
              # --- ungated: static content only ---
              # index.html and root-level files
              #"= /" = proxied;
              "= /manifest.json" = proxied;
              "= /metadata.json" = proxied;
              "= /favicon.ico" = proxied;
              "= /apple-touch-icon.png" = proxied;
              "^~ /_expo/" = proxied;
              "^~ /assets/" = proxied;
              # extension-less client-side routes: the daemon answers these
              # with index.html or a real static file, never dynamic content
              "~ ^/(?!api(/|$)|ws(/|$)|mcp(/|$)|public(/|$))[^./]+(/[^./]+)*$" =
                proxied;
              # anchor navigation can't attach headers; the daemon guards this
              # route with a single-use download token instead
              "^~ /api/files/download" = proxied;

              # --- gated (default deny) ---
              "/ws" = proxied // {
                proxyWebsockets = true;
                extraConfig = ''
                  auth_request /custom-auth;
                  proxy_read_timeout 1800s;
                  proxy_buffering off;
                  proxy_request_buffering off;
                '';
              };
              "^~ /api/" = proxied // {
                extraConfig = ''
                  auth_request /custom-auth;
                  client_max_body_size 0;
                '';
              };
            };
      # `Authorization: Bearer ...` / `X-Bridge-Token`
      "pi.slop.unboiled.info" =  # belt and suspenders
        mkForward "http://192.168.99.53:8787" { proxyWebsockets = true; } {};
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
