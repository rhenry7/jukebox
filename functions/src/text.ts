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
