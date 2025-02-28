{ pkgs, lib, ... }:

{
  accounts.email = {
    maildirBasePath = ".mail";
    accounts."asosedkin@redhat.com" = {
      address = "asosedkin@redhat.com";
      aliases = [ "asosedki@redhat.com" ];
      realName = "Alexander Sosedkin";
      primary = true;
      flavor = "gmail.com";

      notmuch.enable = true;

      lieer = {
        enable = true;
        sync.enable = true;
        sync.frequency = "*:0/3";
        settings.account = "asosedki@redhat.com";
      };

      alot = {
        contactCompletion = {
          type = "shellcommand";
          command = "${pkgs.notmuch-addrlookup}/bin/notmuch-addrlookup ";
          regexp = "(?P<name>.*).*<(?P<email>.+)>";
          ignorecase = "True";
        };
        sendMailCommand = "gmi send -C ~/.mail/asosedkin@redhat.com -t";
        #extraConfig = {
        #  address = "asosedkin@redhat.com";
        #};
      };
    };
  };

  services.lieer.enable = true;

  programs = {
    lieer.enable = true;
    lieer.package = pkgs.lieer;  # TODO: remove later

    notmuch = {
      enable = true;
      extraConfig = {
        user = {
          name = "Alexander Sosedkin";
          primary_email = "asosedkin@redhat.com";
        };
      };
    };

    alot = {
      enable = true;
      bindings = {
        global = {
          h = "bclose";
          n = "move down";
          e = "move up";
          i = "select";
          o = "refresh";
          u = "toggletags unread";
          "/" = "prompt 'search '";
        };
        search = {
          i = "select; fold *; unfold tag:unread; move first";
          U = "search tag:unread; move last";
        };
        thread = {
          h = "bclose; refresh";
          n = "move next";
          e = "move previous";
          "' '" = "move page down";
          o = "fold; untag unread; move next unfolded";
          y = "pipeto 'urlscan -dW 2>/dev/null'";
          r = "reply --all";
          R = "reply";
          u = "fold; untag unread; move next tag:unread";
        };
      };
      settings = {
        attachment_prefix = "~/.downloads/";
        #auto_remove_unread = true;
      };
      hooks = ''
        import alot
        def pre_buffer_focus(ui, dbm, buf):
            if buf.modename == 'search':
                buf.rebuild()
        def pre_buffer_open(ui, dbm, buf):
            current = ui.current_buffer
            if isinstance(current, alot.buffers.SearchBuffer):
                current.focused_thread = current.get_selected_thread()
        def post_buffer_focus(ui, dbm, buf, success):
            if success and hasattr(buf, "focused_thread"):
                if buf.focused_thread is not None:
                    tid = buf.focused_thread.get_thread_id()
                    flag = False
                    for pos, tlw in enumerate(buf.threadlist.get_lines()):
                        flag = True
                        if tlw.get_thread().get_thread_id() == tid:
                            break
                    if flag:
                        buf.body.set_focus(pos)
      '';
      tags = {
        attachment.translated = "a";
        encrypted.translated = "e";
        inbox.translated = "i";
        replied.translated = "r";
        signed.translated = "s";
        unread.translated = "U";
      };
    };
  };

  home = {
    packages = with pkgs; [ w3m urlscan ];
    file.".mailcap".text = "text/html;  w3m -dump -o document_charset=%{charset} '%s'; nametemplate=%s.html; copiousoutput";
    activation.notmuch-symlink = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ln -sf $VERBOSE_ARG \
          $HOME/.config/notmuch/default/config $HOME/.notmuch-config
    '';
  };
}
