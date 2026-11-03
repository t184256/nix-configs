/* Warn or block on piping output through `tail` or `head`
 * since pi already auto-truncates tool output and capping masks problems. */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  // ONLY CONCERN ONESELF WITH: piping into head and tail
  const CAP = /\|\s*(?:head|tail)\s+-/;

  // ALLOW ON: selecting a value in a subshell, $(grep p f | tail -n1) is legit
  const SELECTOR = /\$\([^)]*\|\s*(?:head|tail)\s+-/;
  // ALLOW ON: truncating read-only requests: sometimes backfires
  // but at least can usually be re-requested for cheap
  const LISTING = /(?:^|[;&|]\s*)(?:rg|grep|fd|ls|cat|sed|jq|sort)\b/;
  const GIT_READ = /\bgit\s+(?:log|show|blame|diff)\b/;

  // BLOCK ON: stderr merged into stdout and then eaten:
  // missing crucial output, masked retcode, ...
  const HIDES_STDERR = /\d*>&\s*1\s*\|\s*(?:head|tail)\s+-/;

  // WARN ON: the rest of the piping into head or tail

  let warnings = 0;

  pi.on("tool_call", async (event) => {
    if (event.toolName !== "bash") return;
    const command = event.input.command ?? "";
    if (!CAP.test(command)) return;
    if (SELECTOR.test(command)
        || LISTING.test(command)
        || GIT_READ.test(command))
        return;

    if (HIDES_STDERR.test(command)) {
      return {
        block: true,
        reason:
          "Do not pipe commands through `tail` or `head` "
          + "to be frugal with tokens: "
          + "it can hide stderr, mask retcodes and otherwise cause problems. "
          + "Run it uncapped: pi auto-truncates tool output by itself.\n",
      };
    }

    warnings += 1;
    if (warnings > 3 && warnings % 7 !== 0) return;  // throttle

    pi.sendMessage({
      customType: "no-tail-pipe",
      content:
        "Warning: no need to pipe output through head or tail just "
        + "to be frugal with context; it masks problems. "
        + "omit them next time since long output gets auto-truncated.\n",
    });
  });
}
