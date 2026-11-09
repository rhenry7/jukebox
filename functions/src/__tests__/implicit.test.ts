import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { lovedReviews } from "../forYou";
import { combineImplicit, IMPLICIT_WEIGHTS } from "../implicit";
import { Candidate, scoreCandidate } from "../scoring";
import { ReviewVector } from "../store";

describe("combineImplicit", () => {
  const me = "me";
  it("weights each action and keeps the strongest per review", () => {
    const s = combineImplicit(
      me,
      [
        { type: "like", reviewId: "users/a/reviews/1" },
        { type: "comment", reviewId: "users/a/reviews/1" },
        { type: "comment", reviewId: "users/b/reviews/2" },
        { type: "liked_your_review", reviewId: "users/c/reviews/3" },
      ],
      [{ reviewPath: "users/a/reviews/1" }],
      [],
    );
    assert.equal(s.liked.get("users/a/reviews/1"), IMPLICIT_WEIGHTS.bookmark);
    assert.equal(s.liked.get("users/b/reviews/2"), IMPLICIT_WEIGHTS.comment);
    assert.equal(s.liked.has("users/c/reviews/3"), false, "things done to me aren't my taste");
  });

  it("ignores the user's own reviews", () => {
    const s = combineImplicit(me, [{ type: "repost", reviewId: "users/me/reviews/1" }], [], []);
    assert.equal(s.liked.size, 0);
  });

  it("'Not for me' overrides a like", () => {
    const s = combineImplicit(
      me,
      [{ type: "like", reviewId: "users/a/reviews/1" }],
      [],
      [{ reviewPath: "users/a/reviews/1", reason: "not_for_me" }],
    );
    assert.equal(s.liked.has("users/a/reviews/1"), false);
    assert.ok(s.disliked.has("users/a/reviews/1"));
  });
});

describe("lovedReviews", () => {
  const rv = (path: string, affinity: number) => ({ reviewPath: path, affinity }) as unknown as ReviewVector;
  it("own reviews at or above the threshold plus engaged-with reviews at their weight", () => {
    const loved = lovedReviews({
      positiveReviews: [rv("own/high", 0.9), rv("own/low", 0.3)],
      liked: [{ review: rv("other/1", 0), weight: 0.4 }],
    });
    assert.deepEqual(
      loved.map((l) => [l.review.reviewPath, l.affinity]),
      [
        ["own/high", 0.9],
        ["other/1", 0.4],
      ],
    );
  });
});

describe("song similarity and dislikes in scoring", () => {
  const base: Candidate = {
    reviewPath: "users/b/reviews/1",
    userId: "b",
    trackKey: "a|t",
    artist: "A",
    title: "T",
    tags: [],
    stars: 4,
    affinity: 0.6,
    date: new Date(),
    likes: 0,
    textLength: 300,
    aspects: [],
    styleSim: 0,
    cf: 0,
    sources: new Set(["song"]),
  };

  it("a similar song raises the score and explains itself", () => {
    const s = scoreCandidate({ ...base, songSim: 0.9, songMatch: "Tadow" }, [], []);
    assert.ok(s.score > scoreCandidate(base, [], []).score);
    assert.equal(s.reason, "Similar to Tadow, which you loved");
  });

  it("a disliked artist lowers the score", () => {
    assert.ok(scoreCandidate({ ...base, dislike: 1 }, [], []).score < scoreCandidate(base, [], []).score);
  });
});
