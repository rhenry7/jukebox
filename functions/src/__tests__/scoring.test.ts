import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { RANKING } from "../config";
import { blendNeighborSim, ratingAgreement } from "../neighbors";
import {
  aspectFit,
  aspectPairs,
  bestPerTrack,
  blendRerank,
  Candidate,
  depth,
  diversify,
  rescaleSim,
  ScoredCandidate,
  scoreCandidate,
  UserAspect,
} from "../scoring";
import { affinity, mergedTags, parseSavedTrack, trackKey, truncateAtSentence } from "../text";
import { kmeans, Vec } from "../vectors";

// Synthetic "embeddings": each musical feature is an axis.
const BASS: Vec = [1, 0, 0, 0];
const GUITAR: Vec = [0, 1, 0, 0];
const DRUMS: Vec = [0, 0, 1, 0];
const VOCALS: Vec = [0, 0, 0, 1];

function candidate(overrides: Partial<Candidate>): Candidate {
  return {
    reviewPath: "users/b/reviews/1",
    userId: "b",
    trackKey: "artist|track",
    artist: "Artist",
    title: "Track",
    tags: [],
    stars: 4,
    affinity: 0.6,
    date: new Date(),
    likes: 0,
    textLength: 300,
    aspects: [],
    styleSim: 0,
    cf: 0,
    sources: new Set(["aspect"]),
    ...overrides,
  };
}

const scored = (c: Candidate, score: number): ScoredCandidate => ({
  candidate: c,
  score,
  aspectFit: 0,
  bestPair: null,
  reason: "",
});

// The user from the plan's example: hated the muddy bass, loved the clean guitar.
const user: UserAspect[] = [
  { category: "mix", statement: "muddy bassline", polarity: -0.8, embedding: BASS, reviewTitle: "Track A" },
  { category: "instrumentation", statement: "clean jazz guitar chords", polarity: 0.9, embedding: GUITAR, reviewTitle: "Track A" },
];

describe("polarity-aware aspect matching", () => {
  it("praise-praise and complaint-complaint add, praise-complaint subtracts", () => {
    const pairs = aspectPairs(user, [
      { category: "instrumentation", statement: "crisp jazz guitar", polarity: 1, embedding: GUITAR },
      { category: "mix", statement: "heavy muddy bass", polarity: 1, embedding: BASS },
    ]);
    assert.ok(pairs[0].contribution > 0, "praising the guitar they love helps");
    assert.ok(pairs[1].contribution < 0, "praising the bass they hate hurts");
  });

  it("ranks a 'loved the muddy bass' review below a 'clean guitar' review", () => {
    const bassLover = candidate({
      reviewPath: "p/bass",
      aspects: [{ category: "mix", statement: "thick muddy bass", polarity: 1, embedding: BASS }],
    });
    const guitarLover = candidate({
      reviewPath: "p/guitar",
      aspects: [{ category: "instrumentation", statement: "clean guitar tone", polarity: 1, embedding: GUITAR }],
    });
    // Tests the matching itself, whatever weight tuning currently gives it.
    const w = { ...RANKING.weights, aspectFit: 0.35 };
    const a = scoreCandidate(bassLover, user, [], new Date(), undefined, w);
    const b = scoreCandidate(guitarLover, user, [], new Date(), undefined, w);
    assert.ok(b.score > a.score);
    assert.ok(a.aspectFit < 0 && b.aspectFit > 0);
  });

  it("rewards a shared complaint", () => {
    const fit = aspectFit(
      aspectPairs(user, [{ category: "mix", statement: "bass too muddy", polarity: -1, embedding: BASS }]),
    );
    assert.ok(fit > 0);
  });

  it("ignores unrelated aspects", () => {
    const pairs = aspectPairs(user, [{ category: "rhythm", statement: "drums", polarity: 1, embedding: DRUMS }]);
    assert.equal(pairs[0].contribution, 0);
    assert.equal(rescaleSim(0.2), 0);
  });

  it("explains with the matched praise", () => {
    const s = scoreCandidate(
      candidate({ aspects: [{ category: "instrumentation", statement: "crisp jazz guitar", polarity: 1, embedding: GUITAR }] }),
      user,
      [],
    );
    assert.equal(s.reason, "Also praises crisp jazz guitar, like your review of Track A");
  });
});

describe("review length", () => {
  it("penalises reviews under 100 characters and rewards longer ones", () => {
    assert.equal(depth(40), -1);
    assert.equal(depth(100), 0);
    assert.equal(depth(500), 1);
    assert.equal(depth(2000), 1);
    assert.equal(depth(null), 0, "older docs without a length are neutral");
  });

  it("ranks a long review above an otherwise identical short one", () => {
    // Tests the length rule itself; production currently weights it 0.
    const w = { ...RANKING.weights, depth: 0.15 };
    const short = scoreCandidate(candidate({ reviewPath: "s", textLength: 60 }), user, [], new Date(), undefined, w);
    const long = scoreCandidate(candidate({ reviewPath: "l", textLength: 450 }), user, [], new Date(), undefined, w);
    assert.ok(long.score > short.score);
  });

  it("picks the long review as the track's qualifier", () => {
    const out = bestPerTrack(
      [
        scoreCandidate(candidate({ reviewPath: "short", trackKey: "t|1", textLength: 50 }), user, [], new Date(), undefined, {
          ...RANKING.weights,
          depth: 0.15,
        }),
        scoreCandidate(candidate({ reviewPath: "long", trackKey: "t|1", textLength: 400 }), user, [], new Date(), undefined, {
          ...RANKING.weights,
          depth: 0.15,
        }),
      ],
      new Set(),
    );
    assert.equal(out[0].candidate.reviewPath, "long");
  });
});

describe("track grouping and variety", () => {
  it("keeps the best positive review per track and drops known tracks and negative reviews", () => {
    const out = bestPerTrack(
      [
        scored(candidate({ reviewPath: "a1", trackKey: "x|1" }), 0.4),
        scored(candidate({ reviewPath: "a2", trackKey: "x|1" }), 0.7),
        scored(candidate({ reviewPath: "b", trackKey: "x|2", affinity: -0.5 }), 0.9),
        scored(candidate({ reviewPath: "c", trackKey: "known|1" }), 0.9),
      ],
      new Set(["known|1"]),
    );
    assert.deepEqual(
      out.map((s) => s.candidate.reviewPath),
      ["a2"],
    );
  });

  it("allows one track per artist in the top slots", () => {
    const ranked = [
      scored(candidate({ reviewPath: "1", artist: "Otis", trackKey: "o|1" }), 0.9),
      scored(candidate({ reviewPath: "2", artist: "Otis", trackKey: "o|2" }), 0.85),
      scored(candidate({ reviewPath: "3", artist: "Aretha", trackKey: "a|1" }), 0.5),
    ];
    const out = diversify(ranked, 3, 0.7, 2);
    assert.deepEqual(
      out.map((s) => s.candidate.reviewPath),
      ["1", "3", "2"],
    );
  });

  it("drops weak LLM fits and keeps unseen items after the reranked ones", () => {
    const ranked = [
      scored(candidate({ reviewPath: "a" }), 0.9),
      scored(candidate({ reviewPath: "b" }), 0.5),
      scored(candidate({ reviewPath: "c" }), 0.1),
    ];
    const fits = new Map([
      ["a", { fit: 0.2, reason: "weak" }],
      ["b", { fit: 0.95, reason: "great match" }],
    ]);
    const out = blendRerank(ranked, fits);
    assert.deepEqual(
      out.map((s) => s.candidate.reviewPath),
      ["b", "c"],
    );
    assert.equal(out[0].reason, "great match");
  });
});

describe("interests", () => {
  it("separates two distinct tastes instead of averaging them", () => {
    const vectors = [BASS, BASS, VOCALS, VOCALS];
    const clusters = kmeans(vectors, [1, 1, 1, 1], 2);
    assert.equal(clusters.length, 2);
    for (const c of clusters) assert.equal(c.members.length, 2);
  });
});

describe("collaborative filtering", () => {
  it("rewards agreement and shrinks small overlaps", () => {
    const a = new Map([
      ["t1", 1],
      ["t2", -1],
    ]);
    const same = ratingAgreement(a, new Map(a));
    const opposite = ratingAgreement(a, new Map([["t1", -1], ["t2", 1]]));
    assert.ok(same.sim > opposite.sim);
    assert.ok(same.sim < 1, "two shared tracks are not full confidence");
    assert.equal(opposite.sim, 0);
    assert.equal(blendNeighborSim(0, -0.4), 0);
  });
});

describe("text helpers", () => {
  it("normalises track identity and saved tracks", () => {
    assert.equal(trackKey(" Otis  Redding", "Try a Little Tenderness "), "otis redding|try a little tenderness");
    assert.equal(parseSavedTrack("artist: Otis Redding, song: Try a Little Tenderness"), "otis redding|try a little tenderness");
  });

  it("merges genres and legacy tags like the app does", () => {
    assert.deepEqual(mergedTags({ genres: ["Rock/Indie", "rock"], tags: ["lo-fi"] }), ["Rock", "Indie", "lo-fi"]);
  });

  it("weights stars and words", () => {
    assert.equal(affinity(5, 1), 1);
    assert.ok(affinity(5, -1) > 0, "5 stars with harsh words still leans positive");
    assert.ok(affinity(1, 0.5) < 0);
  });

  it("truncates at a sentence boundary", () => {
    assert.equal(truncateAtSentence("One idea here. Another idea that runs long.", 25), "One idea here.");
  });
});
