_: prev:
let
  patch = oa: {
    patches = (oa.patches or []) ++ [
       ./fix-inconsistent-opening-reasoning-tag.patch
      ./suppress-analytics-message.patch
      ./tokens-on-startup.patch
      ./strip-provider-prefix-from-announcements.patch
      ./compact-tokens-output.patch
      ./reduce-blank-lines.patch
      ./add-litellm-1.108-exceptions.patch  # teach old aider the new *Errors
    ];
  };

  mcp2 = prev.lib.versionAtLeast prev.python3Packages.mcp.version "2";
  posthog = prev.python3Packages.posthog;  # nixpkgs#578265 would fix it
in {
  aider-chat = prev.aider-chat.overridePythonAttrs patch;
  aider-chat-with-playwright =
    prev.aider-chat-with-playwright.overridePythonAttrs patch;

  python3Packages =
    if mcp2 && (posthog.meta.broken or false)
    then prev.python3Packages // {
      posthog = posthog.overridePythonAttrs (oa: {
        meta = oa.meta // { broken = false; };
        disabledTests = (oa.disabledTests or []) ++ [
          "test_prepare_tool_result_delivers_into_call_tool_result_models"
        ];
      });
    } else if mcp2
    then prev.lib.warn
      "posthog is no longer broken with mcp >= 2; the posthog workaround "
      + "in overlays/aider is unneeded"
      prev.python3Packages
    else prev.python3Packages;
}
