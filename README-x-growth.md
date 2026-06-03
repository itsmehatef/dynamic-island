# X Growth Toolkit — @itsmehatef

A working log + toolkit for growing the @itsmehatef X account (indie hacker / AI
agents / iOS / SaaS niche). This documents what we tried, what the live data
showed, and the scripts that automate the loop.

## TL;DR of what we learned

1. **Replies drive reach, not likes.** Across live posts, every tweet that got 7+
   replies broke 250+ impressions; every tweet with 0–1 replies died under 70.
   The algorithm amplifies off early reply velocity. Optimize the first 5 replies.
2. **Vulnerable reflection + an answerable question is the top format.** Best post
   so far: "the hard part isn't the code, it's deciding what NOT to build — what did
   you cut?" → 11 likes / 10 replies / **575 impressions**.
3. **Literal product changelogs flop.** "chop now suggests ingredient swaps" → 17
   impressions. Nobody who doesn't already use the product cares about the feature
   list. Reframe build-in-public as a *struggle/tension*, not a changelog.
4. **Evenings only.** Winners landed 7pm–midnight CT. Every 3pm afternoon post
   flopped (52 / 25 / 22 impressions). Killed the midday slot.
5. **Philosophical/aphoristic tweets underperform for this audience** (1–3
   engagement). Concrete, answerable, identity-tagged ("builders:", "solo devs:")
   questions win.

## How we got here (timeline)

- **Research phase.** Analyzed X's open-sourced ranking algorithm (xAI rewrite,
  May 2026) and a reference growth account (@ttrimoreau). Key algo findings:
  Likes (1.0) > Replies (0.5) > Reposts (0.3) > dwell (0.2) as scoring weights;
  a literal "banger"/`slop_score` classifier demotes low-effort/AI content;
  out-of-network reach is dampened for <1000-follower accounts; author-diversity
  decay suppresses back-to-back posts.
- **First attempt (philosophical tweet).** Posted a crafted philosophical tweet.
  It flopped (1 like). Diagnosis: not a quality problem — wrong format for the
  audience, and a distribution-surface problem.
- **Pivot to proven formats.** Built a weekly plan of builder-questions,
  question+options, and build-in-public posts (see `content/weekly-tweets.md`).
- **Live posting Sun–Tue + analysis.** Pulled real metrics, found the patterns
  above, and revised the plan to v2 (reflection-driven, reply-optimized).
- **Time-of-day correction.** Re-bucketed all posts by real CT time: the
  "evenings only" claim didn't hold — two of the three biggest hits were
  *afternoon*. Morning is genuinely dead (avg 33 imp, 0.3 replies). Conclusion:
  format + reply velocity matter, not the clock. Settled on 3 slots —
  afternoon / evening / night — and dropped morning.
- **v2.1 reply-itch rewrite (teams).** Deployed a copywriter + a "banger-gate"
  critic to rebuild Wed–Sat for maximum reply-itch and high banger-classifier
  scores. 12 tweets, 3/day. 11 of 12 scored ≥83% confidence of passing the
  banger gate; structures deliberately varied (question-first, narrative,
  options, confession) so the week doesn't read as one repeated template.
  The "hot take:" opener was cut (template tell); an "i'll actually reply"
  line was softened (borderline engagement-bait).
- **No-fabrication pass (v2.1a).** Stripped every invented personal story and
  metric the drafts had picked up ("got my first 10 users", "month two solo",
  "shipped a feature at 2am", "built a whole onboarding flow"). Rule going
  forward: tweets are framed as genuine questions, opinions, and relatable
  observations — never as specific events or numbers that didn't happen. Final
  slate lives at the top of `content/weekly-tweets.md`.

## Account snapshot

- Start of effort: **344 followers**. After Sun–Tue live posting: **357 (+13)**.

## Files

| Path | What it is |
|---|---|
| `content/weekly-tweets.md` | The tweet plan. v2 (revised Wed–Sat) at the top, v1 below the divider. |
| `scripts/x_metrics.py` | Read-only puller for follower + per-tweet engagement. Logs dated snapshots to `data/x_*.csv`. App-only bearer token. |
| `scripts/x_post.py` | Posts a tweet live via X API v2 (OAuth 1.0a user context). `--file` or stdin. |
| `data/x_tweets.csv`, `data/x_account.csv` | Metric snapshot history. |

## Credentials (env vars)

- `X_BEARER_TOKEN` — app-only, **read-only** (metrics).
- `X_API_KEY`, `X_API_SECRET`, `X_ACCESS_TOKEN`, `X_ACCESS_TOKEN_SECRET` —
  OAuth 1.0a user context, **read-write** (posting). Confirmed `read-write`.
- `DISCORD_WEBHOOK_URL` — where we mirror the drafts (each tweet as its own
  message so they can be copied individually).

## Operating loop

1. Post from the plan in the **7pm–12am CT** window (2/day).
2. After each post, reply early + sharp on 3–5 big AI/dev threads — replies are
   the reach multiplier.
3. Re-pull metrics (`python3 scripts/x_metrics.py`), compare, adjust the next
   batch toward whatever's getting replies.

## Posting mechanics

- The X API has **no native scheduling** on the public v2 tier, and the dev
  container is ephemeral. So posting is **live, on cue** — not cron-scheduled.
- `scripts/x_post.py` signs `POST /2/tweets` with OAuth 1.0a and prints the
  resulting tweet URL.
