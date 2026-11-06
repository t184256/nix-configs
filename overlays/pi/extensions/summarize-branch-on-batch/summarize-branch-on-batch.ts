// Rewind branch summaries ("summarize branch" on /tree) run on
// litellm/batch instead of the session model: the request is a one-off
// uncached full-input read, which belongs on the cheap 262K model.
// Regular compaction already runs on batch via pi-hot-compact.
import {
  generateBranchSummary,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";

const PROVIDER = "litellm";
const MODEL_ID = "batch";

export default function (pi: ExtensionAPI) {
  pi.on("session_before_tree", async (event, ctx) => {
    const { preparation, signal } = event;
    if (!preparation.userWantsSummary) return;
    const model = ctx.modelRegistry.find(PROVIDER, MODEL_ID);
    if (!model) return; // fall back to default summarization
    const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
    if (!auth.ok) return;
    try {
      const result = await generateBranchSummary(preparation.entriesToSummarize, {
        model,
        signal,
        apiKey: auth.apiKey,
        headers: auth.headers,
        env: auth.env,
        customInstructions: preparation.customInstructions,
        replaceInstructions: preparation.replaceInstructions,
      });
      if (result.aborted || result.error || !result.summary) return;
      return {
        summary: {
          summary: result.summary,
          usage: result.usage,
          details: {
            readFiles: result.readFiles ?? [],
            modifiedFiles: result.modifiedFiles ?? [],
          },
        },
      };
    } catch {
      return; // fall back to default summarization
    }
  });
}
