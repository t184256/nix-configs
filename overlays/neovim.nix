_: super:

{
  neovim-unwrapped =
    if super.lib.versionAtLeast super.neovim-unwrapped.version "0.10"
      then super.neovim-unwrapped
      else super.neovim-unwrapped.overrideAttrs (_: {
        version = "unstable-2024-03-28";
        src = super.fetchFromGitHub {
          owner = "neovim";
          repo = "neovim";
          rev = "dde2cc65fd2ac89ad88b19df08dc03cf1da50316";
          sha256 = "1isc32i50gxprjddsk6n5wglf3cay7myrfbgdfyawhx0ql6c80bh";
        };
      });
}
