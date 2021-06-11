{ config, pkgs, ... }:

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
      alias.tree = "log --graph --oneline --all";
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
      minus-emph-style = "#ffe0e0";
      plus-style = "#e0ffe0";
      plus-emph-style = "#e0ffe0";
    };
  };
  programs.gh = {
    enable = true;
    gitProtocol = "ssh";
  };
  programs.lazygit.enable = true;
}
