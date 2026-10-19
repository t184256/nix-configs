# a dirty hack, should go away.
# see also https://github.com/nixos-cuda/cuda-nixpkgs-override

_: prev: {
  _cuda = prev._cuda.extend (_: super: {
    extensions = (super.extensions or []) ++ [
      (_: prevSet: {
        nccl = prevSet.nccl.override {
          fetchFromGitHub =
            args:
            if args.tag == "v2.32.3-1"
            then prev.fetchFromGitHub (args // {
              forceFetchGit = true;
              hash = "sha256-HB3Q4GdYh3QFmKaS4fNxbz5ARTpYMFPi38MSfT0k7+8=";
            })
            else prev.fetchFromGitHub args;
        };
      })
    ];
  });
}
