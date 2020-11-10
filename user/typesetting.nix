{ config, pkgs, ... }:

let
  withLang = lang: builtins.elem lang config.language-support;
in
{
  home.packages = if (! withLang "tex") then [] else with pkgs; [
    pandoc gnumake
    (texlive.combine { inherit (texlive)
      scheme-minimal
      xetex
      collection-latexrecommended
      collection-fontsrecommended  # TODO: trim
      collection-langcyrillic collection-langenglish
      etoolbox anyfontsize siunitx adjustbox collectbox
    ;})  # haskellPackages.pandoc-emphasize-code
  ];
}
