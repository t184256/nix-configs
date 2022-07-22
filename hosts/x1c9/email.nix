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
          i = "select; fold *; unfold tag:unread; move next unfolded";
          U = "search tag:unread; move last";
        };
        thread = {
          h = "bclose; refresh";
          n = "move next";
          e = "move previous";
          "' '" = "move page down";
          o = "fold; untag unread; move next unfolded";
          y = "pipeto urlscal -dW 2>/dev/null";
          r = "reply --all";
          R = "reply";
        };
      };
      settings = {
        attachment_prefix = "~/.downloads/";
        auto_remove_unread = true;
      };
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
