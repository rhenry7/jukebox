/**
 * Keeps each review's tag-page index fields (`tagKeys`, `tagWordKeys`,
 * `textWordKeys`, see `searchKeys`) in step with its tags and text. The app
 * writes them when posting; this covers older reviews and anything else.
 */
import { Firestore } from "firebase-admin/firestore";
import { ReviewDoc, searchKeys, SearchKeys } from "./text";

/** Whether [data]'s stored keys differ from [keys]. */
export function keysChanged(data: Record<string, unknown>, keys: SearchKeys): boolean {
  return (Object.keys(keys) as (keyof SearchKeys)[]).some(
    (field) => JSON.stringify(data[field] ?? []) !== JSON.stringify(keys[field]),
  );
}

/** Writes the review's keys if they changed. "missing" if it was deleted. */
export async function syncSearchKeys(
  db: Firestore,
  reviewPath: string,
  opts: { dryRun?: boolean } = {},
): Promise<"updated" | "unchanged" | "missing"> {
  const ref = db.doc(reviewPath);
  const snap = await ref.get();
  if (!snap.exists) return "missing";
  const data = snap.data() ?? {};
  const keys = searchKeys(data as Partial<ReviewDoc>);
  if (!keysChanged(data, keys)) return "unchanged";
  if (!opts.dryRun) await ref.update({ ...keys });
  return "updated";
}
