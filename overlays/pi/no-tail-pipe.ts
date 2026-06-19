/* Warn the model when it pipes bash output through `tail` or `head`,
 * since pi already auto-truncates tool output. */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  const TRUNCATION_PATTERNS = [
    /\|\s*2>&1 \| tail -\b/,
    /\|\s*2>&1 \| head -\b/,
  ];

  pi.on("tool_call", async (event) => {
    if (event.toolName !== "bash") return;
    const command = event.input.command ?? "";
    const matched = TRUNCATION_PATTERNS.find((p) => p.test(command));
    if (matched) {
      pi.sendMessage({
        customType: "no-tail-pipe",
        content:
          "Warning: no need to pipe output through head or tail just"
          + " to preserve context; omit it next time since the output"
          + " is already auto-truncated.",
      });
    }
  });
}
