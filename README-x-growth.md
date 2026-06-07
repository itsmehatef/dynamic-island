# X Growth Toolkit — @itsmehatef

A self-contained working system + log for growing the X (Twitter) account
**@itsmehatef** (Hatef Kasraei — indie hacker, AI agents / iOS / SaaS, building
an AI cooking app called **chop**). This README is written for a **cold handoff**:
if you've never seen this project, read this top to bottom and you'll know what
we're doing, what we learned, how the tools work, and what to do next.

---

## 1. The goal

Grow @itsmehatef's reach and follower count on X by posting original tweets that
generate **replies** (the metric that, for this account, actually drives
distribution). We research, draft, score, post, measure, and iterate.

Starting point of the effort: **344 followers**. After the first 3 days of live
posting (Sun–Tue): **357 (+13)**.

---

## 2. The single most important finding

**Replies drive reach. Not likes, not follower count, not time of day.**

Evidence from this account's own live data (impressions are the reach signal):

| Tweet (abbreviated) | Likes | Replies | Impressions |
|---|---:|---:|---:|
| "how did you get your first 100 users?" | 19 | 9 | **862** |
| "the hardest part is deciding what NOT to build…" | 11 | 10 | **575** |
| "what matters most when launching? > pricing > positioning…" | 5 | 8 | **572** |
| "where did your first 10 users come from? > X > reddit…" | 5 | 7 | **263** |
| literal product changelog ("chop suggests ingredient swaps") | 1 | 1 | **17** |
| abstract philosophical aphorism | ~1 | 0 | <70 |

Every post with **7+ replies broke 250+ impressions**. Every post with **0–1
replies died under 70**. The algorithm amplifies off early reply velocity, so
**the job of each tweet is to make people itch to reply.**

### Corollaries we proved
- **Product changelogs flop.** Nobody who doesn't already use chop cares that you
  shipped a feature. Use chop only as a *lens for a relatable struggle*, never as
  a changelog.
- **Abstract / philosophical / aphoristic tweets underperform** for this audience
  (1–3 engagement). Concrete, answerable, identity-tagged questions win.
- **Time of day is mostly noise.** We initially claimed "evenings only," then
  re-bucketed every post by real Central Time and found two of the three biggest
  hits were *afternoon*. Only **early morning is genuinely dead** (avg 33 imp,
  0.3 replies). Conclusion: post **afternoon / evening / night**, skip morning,
  and care more about being present to seed replies than about the exact hour.

---

## 3. What makes people reply (the levers we draft against)

1. **Low-friction self-expression** — they can answer in 2 seconds with their own
   number/tool/story ("where did your first 10 users come from?").
2. **Identity tag up front** — "builders:", "solo devs:", "indie hackers:" gives
   the right people permission to answer.
3. **Confession/"me too" bait** — a relatable admission lowers the bar for others
   to share theirs.
4. **Mild, defensible controversy** — a take people want to agree-and-add to or
   push back on. NOT ragebait (that gets muted, which is an algorithmic negative).
5. **The options list** — 3–4 short vertical options (`> like > this`) → people
   reply with one word or argue for a 5th. Very high reply rate.
6. **A concrete anchor** — a number, tool name, time ("3am"), dollar amount.
7. **An obvious gap to fill** — "what's your pick?", "what am i missing?".

---

## 4. Hard rules (learned the hard way)

- **NO FABRICATION.** Never invent personal events, metrics, or backstory for
  Hatef ("got my first 10 users", "month two solo", "shipped at 2am", "built a
  whole onboarding flow"). Tweets must be genuine **questions, opinions, and
  relatable observations** he can stand behind. This rule exists because an early
  draft batch was full of invented anecdotes and had to be scrubbed (commit
  `dcb6cd9`). First-person *feelings framed as universal* ("the part of launching
  i dread") are OK; claimed *events/numbers* are not.
- **AI-slop bans** (the X "banger" classifier penalizes a `slop_score`): no
  "it's not X, it's Y"; no tricolons for rhetorical lift; no fortune-cookie
  aphorisms; no emoji-as-bullets; no hashtags; no "hot take:" opener (a template
  tell); no engagement-bait begging ("comment below", "RT if…", "i'll actually
  reply"); banned words: unlock, leverage, dive in, game-changer, harsh truth,
  nobody talks about this, let that sink in, the truth is.
- **Vary the structure across the week.** Even if each tweet passes, posting 12
  identically-shaped "3 lines + question" tweets is detectable at the account
  level. Rotate: question-first, pure question, options list, observation.
- **Voice:** lowercase is on-brand, one idea per line, open cold on the sharpest
  word, no throat-clearing, sound lived/from-inside-the-work.
- **Don't post two originals back-to-back** — author-diversity decay suppresses
  the second in the same feed render. Space the day's posts hours apart.
- **After each post, reply early + sharp on 3–5 big AI/dev threads.** Replies on
  bigger accounts borrow their reach and drive profile-clicks → follows. The
  account's single biggest hit ever (105 likes) was a reply, not an original.

---

## 5. The research behind the strategy

Two background investigations informed everything:

- **X's ranking algorithm** (xAI open-source rewrite, commit `0bfc2795`, May
  2026). Key points: scoring weights Likes 1.0 > Replies 0.5 > Reposts 0.3 >
  dwell 0.2; a Grok-based "banger" classifier assigns a `quality_score` and a
  `slop_score` (AI/low-effort content is demoted); out-of-network reach is
  multiplied by a <1 factor and reply-spam detection is harshest on
  <1000-follower accounts; author-diversity decay suppresses back-to-back posts;
  conversations (posts that spark replies) get extra distribution.
- **Reference growth account** (@ttrimoreau, build-in-public/indie niche). Style
  takeaways: one idea per line, cold opens, concrete over abstract, end on a turn
  not a tidy moral, plain words, earned specificity.

---

## 6. Files in this effort

| Path | Purpose |
|---|---|
| `README-x-growth.md` | **This file.** The handoff doc. |
| `content/weekly-tweets.md` | The tweet plan. **Current = v2.1a at the top**, older versions kept below dividers for history. |
| `scripts/x_metrics.py` | Read-only metrics puller. Logs follower + per-tweet engagement snapshots to `data/x_*.csv` and prints a summary. |
| `scripts/x_post.py` | Posts a tweet **live** via X API v2 (OAuth 1.0a user context). Reads from `--file` or stdin; prints the resulting tweet URL. |
| `data/x_account.csv` | Dated account snapshots: followers, following, tweet count, likes given. |
| `data/x_tweets.csv` | Dated per-tweet snapshots: likes/replies/RTs/quotes/bookmarks/total + text. |

**Note:** the repo's primary project ("dynamic-island", a macOS notch utility) is
unrelated — this growth toolkit just lives alongside it on its own branch.

---

## 7. Credentials (env vars)

All credentials are provided via environment variables (never commit them).

| Var | Auth type | Capability |
|---|---|---|
| `X_BEARER_TOKEN` | App-only OAuth 2.0 | **Read-only.** Metrics. (Cannot post.) |
| `X_API_KEY` | OAuth 1.0a consumer key | part of write auth |
| `X_API_SECRET` | OAuth 1.0a consumer secret | part of write auth |
| `X_ACCESS_TOKEN` | OAuth 1.0a user token | part of write auth |
| `X_ACCESS_TOKEN_SECRET` | OAuth 1.0a user secret | part of write auth |
| `DISCORD_WEBHOOK_URL` | Discord webhook | mirror drafts to a Discord channel |
| `USER_X_HANDLE` | — | `itsmehatef` |

The four `X_API_*` / `X_ACCESS_*` vars together give **read-write** user context
(verified via `GET /2/users/me` returning `x-access-level: read-write`). All four
are required to sign a post; the bearer token alone cannot write.

**Account numeric ID:** `1929780852`.

### Gotchas worth knowing
- The X API has **no native tweet scheduling** on the v2 tier we have. Posting is
  **live, on cue** — there is no cron. (We removed an early scheduled GitHub
  Action because the dev container is ephemeral and can't run overnight.)
- Reading metrics costs API credits; if the account's credits are depleted, reads
  return `402 CreditsDepleted`.
- `non_public_metrics`/`organic_metrics` (true impressions per tweet) require the
  posting user's context **and** specific access; we read the **public**
  `impression_count` where available plus likes/replies/RTs.

---

## 8. How to use the tools

### Pull metrics
```bash
cd /home/user/dynamic-island
python3 scripts/x_metrics.py
```
Prints current followers (+ delta vs last snapshot) and the top originals from the
last 7 days, and appends snapshots to `data/x_*.csv`.

### Post a tweet live (only on explicit go-ahead from Hatef)
```bash
# from a file:
python3 scripts/x_post.py --file /tmp/tweet.txt
# or from stdin:
printf 'the tweet text\n\nwith line breaks' | python3 scripts/x_post.py
```
Validates ≤280 chars, signs `POST /2/tweets` with OAuth 1.0a, prints
`https://x.com/itsmehatef/status/<id>` on success.

### Mirror drafts to Discord
Drafts are posted to the Discord channel as **one message per tweet** (each tweet
in its own ``` code block ```) so they can be copied individually — a single big
block selects everything at once, which Hatef explicitly did not want. The webhook
requires a `User-Agent` header (Cloudflare returns 403/error 1010 without one).
The posting scripts used for this live in `/tmp` during a session; the canonical
content is always `content/weekly-tweets.md`.

---

## 9. The operating loop (do this each cycle)

1. **Draft** from `content/weekly-tweets.md` (or generate new ones following the
   levers in §3 and rules in §4).
2. **Post** in the afternoon / evening / night window, on Hatef's cue. Space
   posts hours apart.
3. **Seed replies** — right after posting, reply early and sharp on 3–5 big
   AI/dev threads to drive profile-clicks back to the fresh original.
4. **Measure** — `python3 scripts/x_metrics.py`, compare to prior snapshot.
5. **Iterate** — double down on whatever pulled replies; cut what didn't.

---

## 10. Timeline of what we did

1. **Research.** Analyzed X's ranking algorithm + the @ttrimoreau reference
   account (§5).
2. **First attempt — a crafted philosophical tweet.** It flopped (1 like).
   Diagnosis: wrong format for the audience + a distribution-surface problem, not
   a quality problem.
3. **Pivot to proven formats.** Built a weekly plan of builder-questions,
   question+options, and build-in-public posts. (`91fabbf`)
4. **Simplified posting infra.** Dropped a scheduled GitHub Action (ephemeral
   container can't run it); decided posting is live/on-cue. Expanded plan to 3
   posts/day. (`2d3e10c`)
5. **Enabled live posting.** Set up OAuth 1.0a write access + `x_post.py`,
   verified `read-write`. (`fafecec`)
6. **Posted live Sun–Tue, then analyzed.** Discovered the replies-drive-reach
   finding and the product-changelog/abstract-tweet flops; revised plan to v2.
   (`1e70abf`)
7. **Corrected the time-of-day claim.** Re-bucketed by real CT — "evenings only"
   was wrong; settled on afternoon/evening/night, drop morning.
8. **v2.1 reply-itch rewrite (sub-agent teams).** A copywriter drafted 12 tweets
   (Wed–Sat, 3/day) for maximum reply-itch; a "banger-gate" critic scored each
   against the algorithm; cut "hot take:" openers and softened an engagement-bait
   line. (`d3d5341`)
9. **No-fabrication pass (v2.1a).** Stripped every invented anecdote/metric;
   reframed as genuine questions/opinions/observations. Added the no-fabrication
   rule here and to the plan header. (`dcb6cd9`)

---

## 11. Current state & what's next

- **Branch:** `claude/x-growth-toolkit` (standalone, pushed to origin).
- **Current plan:** `content/weekly-tweets.md` → **v2.1a**, Wed–Sat, 3/day,
  afternoon/evening/night, no fabricated stories.
- **Discord:** the v2.1a slate is mirrored (intro + 12 separate copyable
  messages).
- **Posting status:** Sun–Tue posted; Wed–Sat slate is drafted and ready, **not
  yet posted** — posting happens live on Hatef's cue.

**Next actions:**
1. Post the Wed–Sat slate on cue, one at a time, spaced out.
2. After each, reply on a few live AI/dev threads to seed reach.
3. Re-run `x_metrics.py` after a couple days and compare reply counts; keep the
   shapes that pull replies, cut the rest.
4. The Wed batch is the live test of whether the reply-itch rewrites actually
   out-reply the v1 formats — watch those numbers.
