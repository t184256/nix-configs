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
in {
  aider-chat = prev.aider-chat.overridePythonAttrs patch;
  aider-chat-with-playwright =
    prev.aider-chat-with-playwright.overridePythonAttrs patch;
}
