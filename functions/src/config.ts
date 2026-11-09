import { defineBoolean, defineSecret } from "firebase-functions/params";

/** OpenAI key lives in Secret Manager — never in the client bundle. */
export const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

/** LLM rerank + explanations (plan phase 6). Off until eval shows a lift. */
export const RERANK_ENABLED = defineBoolean("RERANK_ENABLED", { default: false });

export const CHAT_MODEL = "gpt-4o-mini";
export const EMBEDDING_MODEL = "text-embedding-3-small";
/** Firestore vector indexes cap at 2048 dims. */
export const EMBEDDING_DIMS = 1536;

/** Bump when the analysis prompt or embedding text changes; triggers re-analysis. */
export const ANALYSIS_VERSION = 1;

export const COLLECTIONS = {
  reviewVectors: "reviewVectors",
  reviewAspects: "reviewAspects",
  userVectors: "userVectors",
} as const;

/** Tunables for retrieval and ranking (see plan "Scoring"). */
export const RANKING = {
  weights: {
    aspectFit: 0.35,
    styleSim: 0.2,
    cf: 0.2,
    affinity: 0.1,
    tagOverlap: 0.05,
    /** Reviews of artists that sound like ones the user loved (ListenBrainz). */
    artistSim: 0.15,
    quality: 0.05,
    recency: 0.05,
    /** Longer, more descriptive reviews rank higher; under `minReviewLength` is penalised. */
    depth: 0.15,
  },
  /** Reviews shorter than this (characters) carry little signal and rank lower. */
  minReviewLength: 100,
  /** Length at which the depth bonus is maxed out. */
  fullDepthLength: 500,
  maxInterests: 5,
  aspectHitsPerInterest: 200,
  aspectHitsPerNegative: 100,
  styleQueries: 8,
  styleHitsPerQuery: 100,
  neighbors: 20,
  neighborMinAffinity: 0.6,
  /** A review counts as "loved" for similar-artist matching at this affinity. */
  artistMinAffinity: 0.6,
  /** Similar artists queried (Firestore allows 30 values per query). */
  similarArtistQuery: 30,
  /** Reviews read for the similar-artist channel. */
  artistHits: 100,
  mmrLambda: 0.7,
  artistCapTopN: 10,
  recencyHalfLifeDays: 180,
  forYouSize: 100,
  rerankPoolSize: 30,
  rerankMinFit: 0.5,
  rerankBlend: 0.6,
  postReviewMatches: 5,
} as const;
