{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "Alexander Sosedkin";
    userEmail = "monk@unboiled.info";
    extraConfig = {
      alias.ci = "commit";
      alias.co = "checkout";
      alias.ff = "pull --ff-only";
      alias.tree = "log --graph --oneline --all";
      diff.algorithm = "patience";
      merge.conflictStyle = "diff3";
      merge.tool = "vimdiff";
      "mergetool \"vimdiff\"".path = "nvim";
      mergetool.keepBackup = false;
      mergetool.prompt = false;
    };
  };
}
