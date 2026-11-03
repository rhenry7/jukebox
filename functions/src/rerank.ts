/**
 * CF-RAG generation step (plan phase 6): the LLM sees the user's own praise
 * and complaints plus the retrieved candidate reviews, scores stylistic fit
 * and writes the explanation. It can only pick from the given candidates.
 */
import { chatJson } from "./openai";
import { Profile } from "./profile";
import { ScoredCandidate } from "./scoring";
import { truncateAtSentence } from "./text";

interface RerankItem {
  id: number;
  fit: number;
  matched_aspects: string[];
  reason: string;
}

const RERANK_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["items"],
  properties: {
    items: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["id", "fit", "matched_aspects", "reason"],
        properties: {
          id: { type: "integer", description: "Candidate number from the list." },
          fit: { type: "number", description: "0–1: how well this matches the listener's taste." },
          matched_aspects: { type: "array", items: { type: "string" } },
          reason: {
            type: "string",
            description: "One sentence, second person, ≤ 20 words, citing the overlapping sentiment. No names or IDs.",
          },
        },
      },
    },
  },
};

const RERANK_SYSTEM = `You are a music recommendation engine building a personalised "For You" list.
You get a listener's own review history (what they praise and what they complain about) and
candidate reviews written by other people. Judge each candidate by how closely its described
sound, mood and specific features match what the listener PRAISES, and penalise candidates that
celebrate what the listener COMPLAINS about. Read whole sentences; wording and context matter.
Return a fit for every candidate number you were given, and only those numbers.
Reasons must never mention reviewer names or user IDs.`;

export function buildRerankPrompt(profile: Profile, pool: ScoredCandidate[]): string {
  const praise = profile.aspects
    .filter((a) => a.polarity > 0)
    .sort((a, b) => b.polarity - a.polarity)
    .slice(0, 8)
    .map((a) => `- ${a.statement} (in ${a.reviewTitle})`);
  const complaints = profile.aspects
    .filter((a) => a.polarity < 0)
    .sort((a, b) => a.polarity - b.polarity)
    .slice(0, 4)
    .map((a) => `- ${a.statement} (in ${a.reviewTitle})`);
  const quotes = profile.positiveReviews
    .slice(0, 3)
    .map((r) => `- "${r.title}" by ${r.artist}`);

  const candidates = pool.map((s, i) => {
    const c = s.candidate;
    const aspects = c.aspects.map((a) => `${a.polarity >= 0 ? "+" : "−"}${a.statement}`).join(", ");
    return `${i}. "${c.title}" by ${c.artist} — ${c.stars}/5 — aspects: ${aspects || "none"}`;
  });

  return [
    "LISTENER PRAISES:",
    praise.join("\n") || "- (nothing specific yet)",
    "",
    "LISTENER COMPLAINS ABOUT:",
    complaints.join("\n") || "- (nothing specific yet)",
    "",
    "LISTENER RECENTLY LOVED:",
    quotes.join("\n") || "- (no reviews yet)",
    "",
    "CANDIDATES (reviews by other listeners):",
    candidates.join("\n"),
  ].join("\n");
}

/** Attaches each candidate's qualifier review text (truncated at a sentence). */
export function withReviewTexts(prompt: string, pool: ScoredCandidate[], texts: Map<string, string>): string {
  const lines = pool.map((s, i) => {
    const t = texts.get(s.candidate.reviewPath);
    return t ? `${i}. review text: "${truncateAtSentence(t, 600)}"` : "";
  });
  return `${prompt}\n\nCANDIDATE REVIEW TEXTS:\n${lines.filter(Boolean).join("\n")}`;
}

/** Returns reviewPath → {fit, reason}; unknown or invalid ids are ignored. */
export async function rerank(
  apiKey: string,
  profile: Profile,
  pool: ScoredCandidate[],
  reviewTexts: Map<string, string>,
): Promise<Map<string, { fit: number; reason: string }>> {
  const user = withReviewTexts(buildRerankPrompt(profile, pool), pool, reviewTexts);
  const res = await chatJson<{ items: RerankItem[] }>(apiKey, {
    system: RERANK_SYSTEM,
    user,
    schemaName: "for_you_rerank",
    schema: RERANK_SCHEMA,
    timeoutMs: 30_000,
  });
  const out = new Map<string, { fit: number; reason: string }>();
  for (const item of res.items) {
    const s = pool[item.id];
    if (!s || !Number.isInteger(item.id)) continue;
    out.set(s.candidate.reviewPath, {
      fit: Math.max(0, Math.min(1, item.fit)),
      reason: item.reason.trim(),
    });
  }
  return out;
}
