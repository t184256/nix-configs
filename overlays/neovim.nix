_: super:

{
  neovim-unwrapped =
    if super.lib.versionAtLeast super.neovim-unwrapped.version "0.10"
      then super.neovim-unwrapped
      else super.neovim-unwrapped.overrideAttrs (_: {
        version = "v0.10.0-dev-2597+gd326e0486";
        src = super.fetchFromGitHub {
          owner = "neovim";
          repo = "neovim";
          rev = "d326e04860427b0a6a0b66da86fae8e5d23c8a7c";
          sha256 = "sha256-fh81AiAZs5rQHs3udiVJLAq9KWac/PcggHWKjrnXI9o=";
        };
      });
}
