_: super:

{
  bcachefs-tools = super.bcachefs-tools.overrideAttrs (oa: {
    name = "bcachefs-tools-23";
    src = super.fetchFromGitHub {
      owner = "koverstreet";
      repo = "bcachefs-tools";
      rev = "v23";
      sha256 = "sha256-IcrVV5i1/BqA7akLz7+isTfhLWOAxLoUnOOe4DIBg4E=";
    };
  });
}
