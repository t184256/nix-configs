_: super:

{
  tabby-agent =
    if super.lib.versionAtLeast super.tabby-agent.version "0.25.2"
      then super.tabby-agent
      else super.tabby-agent.overrideAttrs (_: rec {
        version = "0.25.2";
        src = super.fetchFromGitHub {
          owner = "TabbyML";
          repo = "tabby-agent";
          rev = "v${version}";
          hash = "sha256-8SUeqIta1CFLVtX7GxOeczSDyi50TTGgyZK2kZJsA+0=";
        };
        pnpmDeps = super.pnpm_9.fetchDeps {
          pname = "tabby-agent";
          inherit version src;
          hash = "sha256-fQnMLjVhscLN0HFyP7ArjytTryZtr1D+gxrvMT0c40k=";
        };
      });
}
