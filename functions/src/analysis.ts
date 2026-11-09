/**
 * Write-time analysis (plan phase 1): read the whole review, extract
 * context-aware sentiment per aspect, embed, and store in the vector
 * collections. Runs once per review (re-runs only when the text, stars or
 * tags change, or ANALYSIS_VERSION is bumped).
 */
import { FieldValue, Firestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { ANALYSIS_VERSION, COLLECTIONS } from "./config";
import { chatJson, embed } from "./openai";
import {
  affinity,
  aspectEmbeddingText,
  contentHash,
  mergedTags,
  normalizeReview,
  reviewDate,
  starsOrPolarity,
  ReviewDoc,
  reviewDocId,
  reviewEmbeddingText,
  starsToPolarity,
  trackKey,
} from "./text";

export const ASPECT_CATEGORIES = [
  "vocals",
  "production",
  "mix",
  "rhythm",
  "instrumentation",
  "lyrics",
  "mood",
  "songwriting",
  "performance",
  "other",
] as const;

export interface AnalysisResult {
  polarity: number;
  tone: string[];
  aspects: { category: string; statement: string; polarity: number; quote: string }[];
}

const ANALYSIS_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["polarity", "tone", "aspects"],
  properties: {
    polarity: { type: "number", description: "Overall sentiment of the text, -1 to 1." },
    tone: {
      type: "array",
      description: "1–4 words for the mood/feel the reviewer describes (e.g. melancholic, late-night, aggressive).",
      items: { type: "string" },
    },
    aspects: {
      type: "array",
      description: "Each distinct thing praised or criticised. 0–6 items.",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["category", "statement", "polarity", "quote"],
        properties: {
          category: { type: "string", enum: [...ASPECT_CATEGORIES] },
          statement: {
            type: "string",
            description: "Short neutral noun phrase naming the feature, e.g. 'clean jazz guitar chords', 'muddy bassline'.",
          },
          polarity: { type: "number", description: "-1 complaint … 1 praise, judged in context." },
          quote: { type: "string", description: "The reviewer's words this came from (≤ 20 words)." },
        },
      },
    },
  },
};

const ANALYSIS_SYSTEM = `You analyse music reviews. Read the WHOLE review before judging anything.
Judge sentiment from full sentences and their context, never from single words:
- negation and hedging ("not bad at all" is positive, "would be great if…" is a complaint),
- contrast ("the bass was muddy, but the guitar saved it" = one complaint, one praise),
- sarcasm and slang ("this slaps" is praise, "sucks" is a complaint).
Statements must name the musical feature itself, without sentiment words, so that two
reviewers describing the same feature produce similar statements.
The star rating is context only; score polarity from the text.`;

export async function analyzeText(
  apiKey: string,
  data: Pick<ReviewDoc, "title" | "artist" | "review" | "score">,
  tags: string[],
): Promise<AnalysisResult> {
  const result = await chatJson<AnalysisResult>(apiKey, {
    system: ANALYSIS_SYSTEM,
    user: `Track: "${data.title}" by ${data.artist}\nStars: ${Number.isFinite(data.score) ? `${data.score}/5` : "not given"}\nTags: ${tags.join(", ") || "none"}\nReview:\n${data.review}`,
    schemaName: "review_analysis",
    schema: ANALYSIS_SCHEMA,
  });
  const clamp = (x: number) => Math.max(-1, Math.min(1, Number(x) || 0));
  return {
    polarity: clamp(result.polarity),
    tone: result.tone.slice(0, 4),
    aspects: result.aspects
      .filter((a) => a.statement.trim())
      .slice(0, 6)
      .map((a) => ({ ...a, statement: a.statement.trim(), polarity: clamp(a.polarity) })),
  };
}

export type AnalyzeOutcome = "analyzed" | "unchanged" | "skipped" | "deleted";

/**
 * Brings the vector docs for one review in line with the review. Idempotent:
 * an unchanged review (same content hash and analysis version) is a no-op.
 */
export async function syncReview(
  db: Firestore,
  apiKey: string,
  reviewPath: string,
  opts: { force?: boolean } = {},
): Promise<AnalyzeOutcome> {
  const id = reviewDocId(reviewPath);
  const vectorRef = db.collection(COLLECTIONS.reviewVectors).doc(id);
  const snap = await db.doc(reviewPath).get();

  if (!snap.exists) {
    await deleteVectors(db, reviewPath);
    return "deleted";
  }
  const data = normalizeReview(snap.data() as Partial<ReviewDoc>, reviewPath);
  if (data.isRepost || !data.review?.trim()) {
    // Reposts are copies; empty reviews have nothing to analyse.
    await deleteVectors(db, reviewPath);
    return "skipped";
  }

  const tags = mergedTags(data);
  const hash = contentHash(data, tags);
  const existing = await vectorRef.get();
  if (
    !opts.force &&
    existing.exists &&
    existing.get("contentHash") === hash &&
    existing.get("analysisVersion") === ANALYSIS_VERSION
  ) {
    return "unchanged";
  }

  let analysis: AnalysisResult;
  let version = ANALYSIS_VERSION;
  try {
    analysis = await analyzeText(apiKey, data, tags);
  } catch (e) {
    // Fall back to stars only; version 0 marks it for the next backfill run.
    logger.warn("LLM analysis failed, using stars only", { reviewPath, error: String(e) });
    analysis = { polarity: Number.isFinite(data.score) ? starsToPolarity(data.score) : 0, tone: [], aspects: [] };
    version = 0;
  }

  const texts = [
    reviewEmbeddingText(data, tags, analysis.tone),
    ...analysis.aspects.map((a) => aspectEmbeddingText(a.category, a.statement)),
  ];
  const [reviewVec, ...aspectVecs] = await embed(apiKey, texts);
  const stars = starsOrPolarity(data.score, analysis.polarity);
  const key = trackKey(data.artist, data.title);
  const date = reviewDate(data);

  const batch = db.batch();
  batch.set(vectorRef, {
    reviewPath,
    userId: data.userId,
    trackKey: key,
    artist: data.artist,
    title: data.title,
    tags,
    // Copied from the review (kept in step by syncMbIds) so ranking has them.
    artistMbids: data.artistMbids ?? [],
    recordingMbid: data.recordingMbid ?? null,
    mbTags: data.mbTags ?? [],
    releaseYear: data.releaseYear ?? null,
    metaTags: data.metaTags ?? [],
    stars,
    likes: data.likes ?? 0,
    textLength: data.review.trim().length,
    polarity: analysis.polarity,
    tone: analysis.tone,
    affinity: affinity(stars, analysis.polarity),
    aspects: analysis.aspects,
    isRepost: false,
    date: date ?? FieldValue.serverTimestamp(),
    embedding: FieldValue.vector(reviewVec),
    contentHash: hash,
    analysisVersion: version,
    analyzedAt: FieldValue.serverTimestamp(),
  });
  const aspectsCol = db.collection(COLLECTIONS.reviewAspects);
  const old = await aspectsCol.where("reviewPath", "==", reviewPath).get();
  old.docs.forEach((d) => batch.delete(d.ref));
  analysis.aspects.forEach((a, i) => {
    batch.set(aspectsCol.doc(`${id}__${i}`), {
      reviewPath,
      userId: data.userId,
      trackKey: key,
      category: a.category,
      statement: a.statement,
      quote: a.quote,
      polarity: a.polarity,
      sign: a.polarity >= 0 ? "pos" : "neg",
      embedding: FieldValue.vector(aspectVecs[i]),
    });
  });
  await batch.commit();
  return "analyzed";
}

export async function deleteVectors(db: Firestore, reviewPath: string): Promise<void> {
  const batch = db.batch();
  batch.delete(db.collection(COLLECTIONS.reviewVectors).doc(reviewDocId(reviewPath)));
  const aspects = await db.collection(COLLECTIONS.reviewAspects).where("reviewPath", "==", reviewPath).get();
  aspects.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}
