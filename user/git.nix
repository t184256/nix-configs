{ config, pkgs, ... }:

let
  git-t = (pkgs.writeShellScriptBin "git-t" ''
    set -ueo pipefail
    refs=""; opts=""; ((c=0))||true
    for arg in $@; do
      if [[ $arg == -* ]]; then
        opts+=" $arg"
      else
        refs+=" $arg"
        ((c++))||true
      fi
    done
    (( $c == 0 )) && exec git log --oneline --graph $opts --all
    (( $c == 1 )) && refs="HEAD $refs"
    exec git log --oneline --graph $opts $refs --not $(git merge-base $refs)^
  '');
in
{
  programs.git = {
    enable = true;
    userName = "Alexander Sosedkin";
    userEmail = config.identity.email;
    extraConfig = {
      alias.tip = "show HEAD";
      alias.ci = "commit";
      alias.sw = "switch";
      alias.ff = "pull --ff-only";
      alias.tree = "log --graph --oneline '--exclude=refs/notes/*' --all";
      alias.mr = "!sh -c 'git fetch $2 merge-requests/$3/head:mr-$2-$3 && git checkout mr-$2-$3'";
      diff.algorithm = "patience";
      init.defaultBranch = "main";
      merge.conflictStyle = "diff3";
      merge.tool = "vimdiff";
      "mergetool \"vimdiff\"".path = "nvim";
      mergetool.keepBackup = false;
      mergetool.prompt = false;
      rerere.enabled = true;

      diff.colorMoved = "default";  # delta eats markers before these *sigh*
      color.diff = {
        meta = "dim";
        frag = "dim";
        func = "dim";
        commit = "#feffd0";
        oldMoved = "#fce0ff";
        newMoved = "#daeeff";
        oldMovedAlternative = "#e0c0e4";
        newMovedAlternative = "#97c4f0";
      };
    };
    delta.enable = true;
    delta.options = {
      whitespace-error-style = "22 reverse";
      syntax-theme = "none";
      zero-style = "#ecf0eb";
      minus-style = "#ffe0e0";
      minus-emph-style = "#ffe0e0 reverse";
      plus-style = "#e0ffe0";
      plus-emph-style = "#e0ffe0 reverse";
      color-only = true;
      max-line-length = 0;  # disable truncation
    };
  };
  #programs.gh = { enable = true; gitProtocol = "ssh"; };  # h-m#1654
  programs.lazygit.enable = true;

  programs.jujutsu.enable = true;

  home.packages = [
    pkgs.git-absorb
    pkgs.gh

    git-t
    (pkgs.writeShellScriptBin "git-v" ''
      (( $# == 0 )) && \
        exec ${git-t}/bin/git-t --ancestry-path "$@" HEAD origin/HEAD
      exec ${git-t}/bin/git-t --ancestry-path "$@"
    '')
  ];
}
