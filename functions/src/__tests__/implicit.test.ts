import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { combineLikedSimilar, likedSeeds, lovedReviews } from "../forYou";
import { combineImplicit, IMPLICIT_WEIGHTS } from "../implicit";
import { becauseYou, Candidate, reasonFor, scoreCandidate } from "../scoring";
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
    assert.equal(s.actions.get("users/a/reviews/1"), "bookmark", "the strongest action is remembered");
    assert.equal(s.actions.get("users/b/reviews/2"), "comment");
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
      liked: [{ review: rv("other/1", 0), weight: 0.4, action: "like" }],
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

describe("liked reviews' More like this", () => {
  const seed = (path: string, title: string, weight: number, action: "like" | "bookmark" | "comment", day = 1) => ({
    review: { reviewPath: path, title, date: new Date(2026, 0, day) } as unknown as ReviewVector,
    weight,
    action,
  });

  it("seeds: strongest action first, then newest", () => {
    const seeds = likedSeeds(
      {
        liked: [
          seed("users/a/reviews/1", "Old like", 0.4, "like", 1),
          seed("users/a/reviews/2", "Saved", 0.6, "bookmark", 1),
          seed("users/a/reviews/3", "New like", 0.4, "like", 9),
        ],
      },
      2,
    );
    assert.deepEqual(
      seeds.map((s) => s.review.title),
      ["Saved", "New like"],
    );
  });

  it("each list top item counts most, scaled by how strongly the user acted", () => {
    const m = combineLikedSimilar(
      [seed("users/a/reviews/1", "Nights", 0.6, "bookmark"), seed("users/b/reviews/2", "Kids", 0.4, "like")],
      [
        [
          { reviewPath: "users/x/reviews/1", score: 0.8, reason: "artist" },
          { reviewPath: "users/x/reviews/2", score: 0.4, reason: "tags" },
          { reviewPath: "users/me/reviews/9", score: 0.7, reason: "text" },
        ],
        [{ reviewPath: "users/x/reviews/2", score: 0.5, reason: "text" }],
      ],
      "me",
    );
    assert.equal(m.get("users/x/reviews/1")?.strength, 0.6);
    assert.equal(m.get("users/x/reviews/1")?.likedTitle, "Nights");
    // Found by both: Kids' list ranks it first (0.4) > half of Nights' (0.3).
    assert.equal(m.get("users/x/reviews/2")?.strength, 0.4);
    assert.equal(m.get("users/x/reviews/2")?.action, "like");
    assert.equal(m.has("users/me/reviews/9"), false, "never the user's own review");
  });

  it("missing or empty lists are skipped", () => {
    const m = combineLikedSimilar([seed("users/a/reviews/1", "Nights", 0.6, "bookmark")], [undefined], "me");
    assert.equal(m.size, 0);
  });

  it("the reason says what the user did", () => {
    assert.equal(becauseYou("bookmark", "Nights"), "Because you saved Nights");
    assert.equal(becauseYou("like", "Kids"), "Because you liked a review of Kids");
    const c = {
      styleSim: 0.2,
      cf: 0,
      likedSim: 0.6,
      likedMatch: "Nights",
      likedAction: "bookmark",
      sources: new Set(["liked"]),
    } as unknown as Candidate;
    assert.equal(reasonFor(c, null, 0), "Because you saved Nights");
    const style = { styleSim: 0.7, cf: 0, styleMatchTitle: "Kids", styleVia: "like", sources: new Set(["style"]) } as unknown as Candidate;
    assert.equal(reasonFor(style, null, 0), "Reads a lot like the review of Kids you liked");
  });
});
