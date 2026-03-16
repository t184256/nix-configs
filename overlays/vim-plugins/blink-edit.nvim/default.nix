pkgs: pkgs.vimUtils.buildVimPlugin {
  pname = "blink-edit-nvim";
  version = "unstable-2026-02-01";
  src = pkgs.fetchFromGitHub {
    owner = "BlinkResearchLabs";
    repo = "blink-edit.nvim";
    rev = "220f5777f5597f6d7868981d6ff9b6218247fec4";
    hash = "sha256-GxO9SlfiOWXAsTtIkAfygISO83BWif3+AktXlHGi0q0=";
  };
  patches = [
    ./0001-add-API-key-auth-support.patch
    ./0002-fix-LSP-position-encoding.patch
    #./0003-add-BlinkEditAnchor-underline-on-modified-characters.patch
    #./0004-fix-off-by-one-in-render-lnum-calculations.patch
    #./0005-three-stage-accept-marker-jump-preview-apply.patch
  ];
}
