import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { affinity, normalizeReview, starsOrPolarity, trackKey } from "../text";

describe("normalizeReview", () => {
  it("fills fields older reviews lack", () => {
    const r = normalizeReview({ review: "great" }, "users/u1/reviews/r1");
    assert.equal(r.userId, "u1");
    assert.equal(r.artist, "");
    assert.equal(r.title, "");
    assert.ok(Number.isNaN(r.score));
    // trackKey used to throw on a missing artist/title.
    assert.equal(trackKey(r.artist, r.title), "|");
  });

  it("keeps fields that are present", () => {
    const r = normalizeReview(
      { userId: "u2", artist: "A", title: "T", review: "x", score: 4 },
      "users/u1/reviews/r1",
    );
    assert.deepEqual([r.userId, r.artist, r.title, r.score], ["u2", "A", "T", 4]);
  });
});

describe("starsOrPolarity", () => {
  it("uses the stars when given", () => {
    assert.equal(starsOrPolarity(2, 1), 2);
  });

  it("derives stars from the words when missing", () => {
    assert.equal(starsOrPolarity(NaN, 1), 5);
    assert.equal(starsOrPolarity(NaN, -1), 0);
    assert.equal(starsOrPolarity(NaN, 0), 2.5);
    // So affinity follows the text alone.
    assert.ok(affinity(starsOrPolarity(NaN, 0.8), 0.8) > 0.7);
  });
});
