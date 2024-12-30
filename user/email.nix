{ config, pkgs, lib, ... }:

{
  accounts.email = lib.mkIf (config.roles.mua) {
    maildirBasePath = ".mail";
    accounts."monk@unboiled.info" = {
      address = "monk@unboiled.info";
      realName = "Alexander Sosedkin";
      gpg.key = "B0E9DD20B29F1432";
      primary = true;

      userName = "monk@unboiled.info";
      imap = {
        host = "unboiled.info";
        tls = { enable = true; useStartTls = true; };
      };
      smtp = {
        host = "unboiled.info";
        tls = { enable = true; };
      };
      passwordCommand = "${pkgs.pass}/bin/pass show services/unboiled.info/mail/monk@unboiled.info";

      msmtp.enable = true;

      offlineimap = {
        enable = true;
        extraConfig.account = { autorefresh = 20; };
        extraConfig.remote = {
          holdconnectionopen = "yes";
          idlefolders = "['Inbox']";
        };
        postSyncHookCommand = "${pkgs.notmuch}/bin/notmuch new";
      };

      notmuch.enable = true;

      alot = {
        contactCompletion = {
          type = "shellcommand";
          command = "${pkgs.notmuch-addrlookup}/bin/notmuch-addrlookup ";
          regexp = "(?P<name>.*).*<(?P<email>.+)>";
          ignorecase = "True";
        };
      };
    };
  };


  programs = lib.mkIf (config.roles.mua) {
    msmtp.enable = true;
    offlineimap.enable = true;

    notmuch = {
      enable = true;
      extraConfig = {
        user = {
          name = "Alexander Sosedkin";
          primary_email = "monk@unboiled.info";
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
        thread = {
          h = "bclose";
          n = "move next";
          e = "move previous";
          "' '" = "move page down";
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


  home = lib.mkIf (config.roles.mua) {
    packages = [ pkgs.w3m ];
    file.".mailcap".text = "text/html;  w3m -dump -o document_charset=%{charset} '%s'; nametemplate=%s.html; copiousoutput";
    activation.notmuch-symlink = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ln -sf $VERBOSE_ARG \
          $HOME/.config/notmuch/default/config $HOME/.notmuch-config
    '';
  };
}
