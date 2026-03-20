_: prev:
# Fix reasoning_tag_name not used when opening streaming reasoning block.
# https://github.com/Aider-AI/aider/blob/main/aider/coders/base_coder.py#L1937
let
  patch = oa: {
    patches = (oa.patches or []) ++ [
      ./fix-inconsistent-opening-reasoning-tag.patch
      ./suppress-analytics-message.patch
      ./tokens-on-startup.patch
      ./strip-provider-prefix-from-announcements.patch
      ./compact-tokens-output.patch
      ./reduce-blank-lines.patch
    ];
  };
in {
  aider-chat = prev.aider-chat.overridePythonAttrs patch;
  aider-chat-with-playwright = prev.aider-chat-with-playwright.overridePythonAttrs patch;
}
