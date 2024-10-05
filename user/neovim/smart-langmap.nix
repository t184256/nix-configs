{ config, pkgs, ... }:

{
  programs.nixvim = {
    opts = {
      langmap =
        "№" +
        "йцукенгшщзх" +   "фывапролджэ" +    "ячсмитьбю" +
        "ЙЦУКЕНГШЩЗХ" +   "ФЫВАПРОЛДЖЭ" +    "ЯЧСМИТЬБЮ" +
        ";" +
        "#" +
        "qwfpgjluy\\;-" + "arstdhneio'" +    "zxcvbkm\\,." +
        "QWFPGJLUY:\\|" + "ARSTDHNEIO\\\"" + "ZXCVBKM<>";
    };
    keymaps = [
      { key = "<Insert><Insert>.";  mode = [ "n" "v" ]; action = "/"; }  # .->/
      { key = "<Insert><Insert>;";  mode = [ "n" "v" ]; action = "$"; }  # ;->$
      { key = "<Insert><Insert>\""; mode = [ "n" "v" ]; action = "@"; }  # "->@
      { key = "<Insert><Insert>:";  mode = [ "n" "v" ]; action = "^"; }  # :->^
      { key = "<Insert><Insert>?";  mode = [ "n" "v" ]; action = "&"; }  # ?->&
      { key = "<Insert><Insert>,";  mode = [ "n" "v" ]; action = "?"; }  # ,->?
      { key = "ъ";  mode = [ "v" ]; action = "<Esc>"; }
      { key = "ъъ";  mode = [ "i" ]; action = "<Esc>"; }
    ];
  };
}
