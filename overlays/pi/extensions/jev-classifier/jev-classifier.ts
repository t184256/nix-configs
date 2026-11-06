// Registers d1-3B as a classifier model for pi-advisor's Jev.
// models.json cannot declare classifier models
// https://github.com/earendil-works/pi/issues/10791
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const PROVIDER = "classifier";
const BASE_URL = "https://llm.slop.unboiled.info/v1";
const MODEL_ID = "d1-3B";

type Question = { type: string; criteria?: unknown; instructions?: string };

export default function (pi: ExtensionAPI) {
  pi.registerProvider(PROVIDER, {
    name: "classifier (llama.cpp System One)",
    apiKey: "$LLAMA_KEY",
    models: [
      {
        type: "classifier",
        id: MODEL_ID,
        name: MODEL_ID,
        api: "typesafe-system-one",
        baseUrl: BASE_URL,
        input: ["text"],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: 32768,
      },
    ],
    classifiers: {
      "typesafe-system-one": {
        classify: async (
          model: { id: string; provider: string; api: string },
          context: { state: unknown; questions: Record<string, Question> },
          options?: { apiKey?: string; signal?: AbortSignal }
        ) => {
          const key = options?.apiKey ?? process.env.LLAMA_KEY;
          if (!key) throw new Error("No API key for provider: classifier");
          // Public `bool` questions map to wire-level `noul`.
          const request = {
            model: model.id,
            state: context.state,
            questions: Object.fromEntries(
              Object.entries(context.questions).map(([id, q]) => [
                id,
                q.type === "bool" ? { ...q, type: "noul" } : q,
              ]),
            ),
          };
          const url = `${BASE_URL.replace(/\/+$/u, "")}/systemone`;
          const response = await fetch(url, {
            method: "POST",
            headers: { "content-type": "application/json", authorization: `Bearer ${key}` },
            body: JSON.stringify(request),
            signal: options?.signal,
          });
          const body: any = await response.json().catch(() => undefined);
          if (!response.ok || !body) {
            throw new Error(`System One API error: ${JSON.stringify(body) ?? response.status}`);
          }
          const answers: Record<string, unknown> = {};
          for (const [id, question] of Object.entries(context.questions)) {
            const answer = body.answers?.[id];
            if (question.type === "bool") {
              if (answer?.type !== "noul" || typeof answer.noul !== "number")
                throw new Error(`System One API did not return a bool answer for ${id}`);
              answers[id] = { type: "bool", probability: answer.noul };
            } else if (question.type === "choice") {
              if (answer?.type !== "choice" || typeof answer.choice !== "string")
                throw new Error(`System One API did not return a choice answer for ${id}`);
              answers[id] = {
                type: "choice",
                choice: answer.choice,
                probabilities: answer.probabilities ?? {},
                confidence: answer.confidence ?? 0,
              };
            } else {
              if (answer?.type !== "score")
                throw new Error(`System One API did not return a score answer for ${id}`);
              answers[id] = { type: "score", score: answer.score, confidence: answer.confidence ?? 0 };
            }
          }
          const usage =
            typeof body.usage?.input_tokens === "number" || typeof body.usage?.output_tokens === "number"
              ? {
                  input: body.usage.input_tokens ?? 0,
                  output: body.usage.output_tokens ?? 0,
                  cacheRead: 0,
                  cacheWrite: 0,
                  totalTokens: (body.usage.input_tokens ?? 0) + (body.usage.output_tokens ?? 0),
                  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
                }
              : undefined;
          return {
            api: model.api,
            provider: model.provider,
            model: model.id,
            answers,
            usage,
            stopReason: "stop",
            timestamp: Date.now(),
          };
        },
      },
    },
  });
}
