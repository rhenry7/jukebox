/**
 * How rare each tag is across all reviews (author tags + filled-in
 * `mbTags`), stored in `stats/tags` (server-only) and refreshed nightly.
 * Ranking uses it so sharing "darkwave" counts more than sharing "rock".
 */
import { FieldValue, Firestore } from "firebase-admin/firestore";
import { tagIdf, TagIdf } from "./relevance";
import { mergedTags } from "./text";

const DOC = "stats/tags";
/** Reuse a loaded table for this long within one function instance. */
const CACHE_MS = 60 * 60 * 1000;
let cached: { idf: TagIdf; at: number } | null = null;

export async function computeTagIdf(db: Firestore): Promise<{ reviews: number; tags: number }> {
  const snap = await db.collectionGroup("reviews").select("genres", "tags", "mbTags", "isRepost").get();
  const docs = snap.docs
    .filter((d) => d.ref.path.startsWith("users/") && !d.get("isRepost"))
    .map((d) => [...mergedTags(d.data()), ...((d.get("mbTags") as string[] | undefined) ?? [])]);
  const idf = tagIdf(docs);
  await db.doc(DOC).set({
    // Firestore field names can't contain "/" etc.; store as a list.
    idf: [...idf].map(([tag, weight]) => ({ tag, weight: Number(weight.toFixed(4)) })),
    reviews: docs.length,
    updatedAt: FieldValue.serverTimestamp(),
  });
  cached = { idf, at: Date.now() };
  return { reviews: docs.length, tags: idf.size };
}

/** The stored table, or an empty one (every tag weighted equally) if none yet. */
export async function loadTagIdf(db: Firestore): Promise<TagIdf> {
  if (cached && Date.now() - cached.at < CACHE_MS) return cached.idf;
  const snap = await db.doc(DOC).get();
  const rows = (snap.get("idf") as { tag: string; weight: number }[] | undefined) ?? [];
  const idf: TagIdf = new Map(rows.map((r) => [r.tag, r.weight]));
  cached = { idf, at: Date.now() };
  return idf;
}
