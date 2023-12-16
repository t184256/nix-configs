{ pkgs, config, ... }:

{
  imports = [ ./config/os.nix ];

  programs.tmux = {
    enable = true;
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    terminal = "tmux-256color";
    aggressiveResize = true;
    keyMode = "vi";
    secureSocket = false;  # survives user logout
    shortcut = "a";
    extraConfig = ''
      set -ga terminal-overrides ",*256col*:Tc"
      set -g set-titles on
      set -g set-titles-string "#I > #T"
      set -g status-style bg=white,fg=black
      set -g mode-style bg=white,fg=black
      set -g message-style bg=white,fg=black
      set -g message-command-style bg=white,fg=black
      set -g status off
      set -g default-shell ${pkgs.my-xonsh}/bin/xonsh
      set -g display-time 1000
      set-window-option -g visual-bell on
      set-window-option -g bell-action other
    '';
  };

  home.file.".tmux.sh" = { executable = true; text = ''
    #!/bin/sh
    unset TMUX
    exec tmux new-session -A -t main -s $(date +%s)
  ''; };

  home.file.".tmux-hopper.sh" = { executable = true; text = ''
    #!/bin/sh
    exec tmux -f $HOME/.tmux-hopper.conf -L hopper new-session
  ''; };

  home.file.".tmux-hopper.conf".text = ''
    set -ga terminal-overrides ",*256col*:Tc"
    set -g base-index 0
    set -g escape-time 0
    set -g default-terminal tmux-256color
    set -g aggressive-resize on
    set -g status off
    set-option -g prefix C-b
    unbind C-a
    bind b send-prefix
    bind C-b last-window
    set -g status-style bg=colour234,fg=white
    set -g mode-style bg=colour234,fg=white
    set -g message-style bg=colour234,fg=white
    set -g message-command-style bg=colour234,fg=white
    set -g default-command ~/.tmux-hop.sh
    set -g set-titles on
    set -g set-titles-string "#W > #T"
    bind-key c command-prompt -p "hop to:" "new-window -n %1 ~/.tmux-hop.sh %1"
    set -g destroy-unattached on
  '' + (if (config.system.os != "Nix-on-Droid") then "" else ''
    set -g status-style bg=black,fg=colour244
    set -g status
    set -g status-position top
    set -g status-justify centre
    set -g status-left ""
    set -g status-right ""
    set -g window-status-current-format "#T"
  '');

  home.file.".tmux-hop.sh" = { executable = true; text = ''
    #!/usr/bin/env bash
    set +ue
    export MOSH_TITLE_NOPREFIX=1
    LOCAL=''$(${pkgs.hostname}/bin/hostname)
    TO=''${1:-$LOCAL}
    MOSH_OPTS=""
    case $TO in
      -)      TO=$LOCAL-;     METHOD=shell ;;
      $LOCAL) TO=$LOCAL;      METHOD=attach ;;
      f*)     TO=fig;         METHOD=mosh ;;
      m*)     TO=mango;       METHOD=mosh ;;
      d*)     TO=duckweed;    METHOD=mosh ;;
      l*)     TO=loquat;      METHOD=mosh ;;
      c*)     TO=cocoa;       METHOD=mosh     MOSH_OPTS='-p 22700:22799' ;;
      q*)     TO=quince;      METHOD=mosh     MOSH_OPTS='-p 22600:22699' ;;
      b*)     TO=bayroot;     METHOD=ssh ;;
      a*)     TO=araceae;     METHOD=ssh ;;
    esac
    tmux rename-window $TO 2> /dev/null
    ${pkgs.ncurses}/bin/clear; echo "$METHOD to $TO..."
    case $METHOD in
      shell)  exec bash ;;
      attach) exec ~/.tmux.sh ;;
      mosh)   exec mosh $MOSH_OPTS $TO -o -- ~/.tmux.sh ;;
      mosh-)  exec mosh $MOSH_OPTS $TO -o -- sh -c 'exec tmux new-session -A -t main -s $(date +%s)';;
      ssh)    exec ssh $TO -t ~/.tmux.sh ;;
      ssh-)   exec ssh $TO -t sh -c 'exec tmux new-session -A -t main -s $(date +%s)' ;;
    esac
  ''; };

  home.wraplings = {
    tmux-hop = "~/.tmux-hop.sh";
    tmux-hopper = "~/.tmux-hopper.sh";
  };
}
