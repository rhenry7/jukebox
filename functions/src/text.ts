/** Text normalisation shared by analysis, retrieval and scripts. */

export interface ReviewDoc {
  userId: string;
  artist: string;
  title: string;
  review: string;
  score: number;
  genres?: string[];
  tags?: string[];
  date?: { toDate(): Date } | Date | null;
  likes?: number;
  isRepost?: boolean;
  /** MusicBrainz IDs and filled-in tags, written by `syncMbIds`. */
  artistMbids?: string[];
  recordingMbid?: string | null;
  mbTags?: string[];
}

/**
 * Fills fields that older reviews lack, with the same defaults as
 * `Review.fromFirestore` in the app; the author comes from the path
 * (users/{uid}/reviews/{id}). A missing star score stays NaN — see
 * `starsOrPolarity`.
 */
export function normalizeReview(data: Partial<ReviewDoc>, reviewPath: string): ReviewDoc {
  const score = typeof data.score === "number" ? data.score : Number(data.score);
  return {
    ...data,
    userId: data.userId || reviewPath.split("/")[1] || "",
    artist: data.artist ?? "",
    title: data.title ?? "",
    review: data.review ?? "",
    score: Number.isFinite(score) ? score : NaN,
  };
}

/** The review's stars, or — when it has none — the stars its words imply. */
export function starsOrPolarity(score: number, textPolarity: number): number {
  return Number.isFinite(score) ? score : ((textPolarity + 1) / 2) * 5;
}

/** One identity per song: the same track reviewed by many users groups together. */
export function trackKey(artist: string, title: string): string {
  const norm = (s: string) => s.toLowerCase().replace(/\s+/g, " ").trim();
  return `${norm(artist)}|${norm(title)}`;
}

/** Firestore doc id for a review path (users/u/reviews/r → users__u__reviews__r). */
export function reviewDocId(reviewPath: string): string {
  return reviewPath.replace(/\//g, "__");
}

/**
 * Merges `genres` and legacy `tags`, splitting "a/b" values and de-duping by
 * lowercase — same behaviour as `Review.fromFirestore` in the app.
 */
export function mergedTags(data: Pick<ReviewDoc, "genres" | "tags">): string[] {
  const raw = [...(data.genres ?? []), ...(data.tags ?? [])];
  const seen = new Set<string>();
  const out: string[] = [];
  for (const value of raw) {
    for (const part of String(value).split("/")) {
      const tag = part.trim();
      const key = tag.toLowerCase();
      if (tag && !seen.has(key)) {
        seen.add(key);
        out.push(tag);
      }
    }
  }
  return out;
}

export function reviewDate(data: Pick<ReviewDoc, "date">): Date | null {
  const d = data.date;
  if (!d) return null;
  return d instanceof Date ? d : d.toDate();
}

/** Stars (0–5) → [-1, 1]; 2.5 stars is neutral. */
export function starsToPolarity(stars: number): number {
  return Math.max(-1, Math.min(1, (stars / 5) * 2 - 1));
}

/** How much the reviewer liked the track: stars and the words both count. */
export function affinity(stars: number, textPolarity: number): number {
  return 0.6 * starsToPolarity(stars) + 0.4 * textPolarity;
}

/** Text embedded for the whole review — captures overall style and voice. */
export function reviewEmbeddingText(
  data: Pick<ReviewDoc, "title" | "artist" | "review">,
  tags: string[],
  tone: string[],
): string {
  return [
    `${data.title} by ${data.artist}.`,
    tags.length ? `Tags: ${tags.join(", ")}.` : "",
    tone.length ? `Tone: ${tone.join(", ")}.` : "",
    data.review,
  ]
    .filter(Boolean)
    .join(" ");
}

/** Normalised aspect phrasing so different writers' wording lands close together. */
export function aspectEmbeddingText(category: string, statement: string): string {
  return `${category}: ${statement}`;
}

/** Changes when anything the analysis depends on changes (text, stars, tags). */
export function contentHash(data: Pick<ReviewDoc, "review" | "score">, tags: string[]): string {
  const s = `${data.review}\u0000${data.score}\u0000${tags.join(",")}`;
  let h = 5381;
  for (let i = 0; i < s.length; i++) h = ((h * 33) ^ s.charCodeAt(i)) >>> 0;
  return h.toString(36);
}

/** Parses the app's saved-track format: "artist: X, song: Y". */
export function parseSavedTrack(saved: string): string | null {
  const m = /^artist:\s*(.*?),\s*song:\s*(.*)$/i.exec(saved);
  return m ? trackKey(m[1], m[2]) : null;
}

/** Cuts at a sentence boundary so the LLM never sees half a thought. */
export function truncateAtSentence(text: string, max: number): string {
  if (text.length <= max) return text;
  const cut = text.slice(0, max);
  const end = Math.max(cut.lastIndexOf(". "), cut.lastIndexOf("! "), cut.lastIndexOf("? "));
  return end > max * 0.5 ? cut.slice(0, end + 1) : `${cut.trimEnd()}…`;
}

// ── Search keys (tag page index) ────────────────────────────────────────────
// Must match `searchKeysFor` in lib/providers/tag_reviews_provider.dart; both
// are tested against src/__tests__/fixtures/search_keys.json.

/** Words too generic to make two tags similar on their own. */
const GENERIC_TAG_WORDS = new Set(["music", "and", "the", "of", "song", "songs"]);

/** Common words left out of `textWordKeys`. */
const STOPWORDS = new Set([
  "a", "an", "and", "the", "of", "to", "in", "on", "for", "is", "it", "its",
  "this", "that", "with", "as", "at", "be", "but", "by", "are", "was", "were",
  "i", "im", "my", "me", "so", "or", "if", "you", "your", "we", "they", "he",
  "she", "his", "her", "them", "than", "then", "there", "from", "have", "has",
  "had", "do", "does", "did", "not", "no", "just", "very", "too", "also",
]);

/** How many distinct words of a review's text are indexed. */
export const MAX_TEXT_WORD_KEYS = 150;

/**
 * Lowercase, with spelling variants folded together: "R&B", "rnb" and
 * "R and B" → "r&b"; "hip-hop" and "hiphop" → "hip hop". Same as
 * `normalizeTag` in the app.
 */
export function normalizeTag(tag: string): string {
  let t = tag.toLowerCase().trim().replace(/[-_]+/g, " ");
  t = t.replace(/\s+/g, " ");
  t = t.replace(/\b(rnb|r ?n ?b|r and b|r ?& ?b)\b/g, "r&b");
  t = t.replace(/\bhiphop\b/g, "hip hop");
  return t;
}

/** Normalized words of [text], in order (letters, digits and "&"). */
export function textWords(text: string): string[] {
  return normalizeTag(text)
    .split(/[^\p{L}\p{N}&]+/u)
    .filter((w) => w.length >= 2 && /[\p{L}\p{N}]/u.test(w));
}

export interface SearchKeys {
  tagKeys: string[];
  tagWordKeys: string[];
  textWordKeys: string[];
}

/**
 * The tag page's index fields for a review: its normalized tags, the
 * meaningful words of those tags (for similar tags), and the distinct words
 * of its text (for "mentions"). Reposts get none, so they never match.
 */
export function searchKeys(
  data: Partial<Pick<ReviewDoc, "genres" | "tags" | "review" | "isRepost">>,
): SearchKeys {
  if (data.isRepost) return { tagKeys: [], tagWordKeys: [], textWordKeys: [] };
  const tagKeys = new Set<string>();
  const tagWordKeys = new Set<string>();
  for (const tag of mergedTags(data)) {
    const key = normalizeTag(tag);
    if (!key) continue;
    tagKeys.add(key);
    for (const word of key.split(" ")) {
      if (word && !GENERIC_TAG_WORDS.has(word)) tagWordKeys.add(word);
    }
  }
  const textWordKeys = new Set<string>();
  for (const word of textWords(data.review ?? "")) {
    if (textWordKeys.size >= MAX_TEXT_WORD_KEYS) break;
    if (!STOPWORDS.has(word)) textWordKeys.add(word);
  }
  const sorted = (s: Set<string>) => [...s].sort();
  return {
    tagKeys: sorted(tagKeys),
    tagWordKeys: sorted(tagWordKeys),
    textWordKeys: sorted(textWordKeys),
  };
}
