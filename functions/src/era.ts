/**
 * Release year and era: hidden metadata for recommendations.
 *
 * Each review gets `releaseYear` (the song's first release, from
 * MusicBrainz) and `metaTags` such as "decade:1970s" and "era:classic".
 * Neither is shown in the app or used by tag pages and filters; they're for
 * ranking (For You's era fit, "More like this"'s same-era signal) and future
 * features. Pure functions only (unit-tested).
 */

/** The year in a MusicBrainz date ("2017-10-06", "1975"), or null. */
export function yearFrom(date: unknown): number | null {
  const m = typeof date === "string" ? date.match(/^(\d{4})/) : null;
  const year = m ? Number(m[1]) : NaN;
  return year >= 1900 && year <= new Date().getFullYear() + 1 ? year : null;
}

/** Broad eras, oldest first: [name, first year]. */
const ERAS: [string, number][] = [
  ["early", 0], // before rock & roll
  ["golden", 1955], // rock & roll, soul, Motown, the British Invasion
  ["classic", 1970], // classic rock, disco, funk, punk, early hip hop
  ["modern", 1990], // grunge, golden-age hip hop, R&B, Britpop, the 2000s
  ["streaming", 2010], // the streaming era
];

/** Hidden tags for a release year: decade and era. Empty without a year. */
export function metaTagsFor(year: number | null): string[] {
  if (year === null) return [];
  const era = [...ERAS].reverse().find(([, from]) => year >= from)![0];
  return [`decade:${Math.floor(year / 10) * 10}s`, `era:${era}`];
}

/** How many years apart two songs can be and still feel "of an era". */
const ERA_SCALE_YEARS = 6;

/** 0–1 closeness of two release years: 1 the same year, ~0.5 four years apart. */
export function yearSimilarity(a: number | null | undefined, b: number | null | undefined): number {
  if (a == null || b == null) return 0;
  return Math.exp(-Math.abs(a - b) / ERA_SCALE_YEARS);
}

/**
 * 0–1: how well [year] fits the eras of the music a user loves
 * ([loved]: their songs' years with 0–1 weights), as a weighted average of
 * closeness. 0 when either side has no years.
 */
export function eraFit(year: number | null | undefined, loved: { year: number; weight: number }[]): number {
  if (year == null || loved.length === 0) return 0;
  let sum = 0;
  let total = 0;
  for (const l of loved) {
    sum += l.weight * yearSimilarity(year, l.year);
    total += l.weight;
  }
  return total > 0 ? sum / total : 0;
}
