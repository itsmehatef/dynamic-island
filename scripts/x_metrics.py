#!/usr/bin/env python3
"""Pull @itsmehatef engagement + follower metrics from the X API and log them.

Appends a dated snapshot to data/x_tweets.csv and data/x_account.csv, then prints
a summary: current followers (+ delta since last run) and the top original tweets
by engagement over the last 7 days. Read-only; uses the app-only bearer token.
"""
import csv
import json
import os
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone, timedelta

UID = "1929780852"
HANDLE = "itsmehatef"
BEARER = os.environ.get("X_BEARER_TOKEN")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
TWEETS_CSV = os.path.join(DATA, "x_tweets.csv")
ACCOUNT_CSV = os.path.join(DATA, "x_account.csv")


def api(url):
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {BEARER}"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        print(f"API error {e.code}: {body}", file=sys.stderr)
        sys.exit(1)


def last_account_row():
    if not os.path.exists(ACCOUNT_CSV):
        return None
    with open(ACCOUNT_CSV) as f:
        rows = list(csv.DictReader(f))
    return rows[-1] if rows else None


def main():
    if not BEARER:
        print("X_BEARER_TOKEN not set", file=sys.stderr)
        sys.exit(1)
    os.makedirs(DATA, exist_ok=True)
    now = datetime.now(timezone.utc)
    stamp = now.strftime("%Y-%m-%d %H:%M")

    # --- account metrics ---
    prof = api(
        f"https://api.twitter.com/2/users/by/username/{HANDLE}"
        "?user.fields=public_metrics"
    )["data"]["public_metrics"]
    prev = last_account_row()
    new_account = not os.path.exists(ACCOUNT_CSV)
    with open(ACCOUNT_CSV, "a", newline="") as f:
        w = csv.writer(f)
        if new_account:
            w.writerow(["snapshot", "followers", "following", "tweets", "likes_given"])
        w.writerow([stamp, prof["followers_count"], prof["following_count"],
                    prof["tweet_count"], prof["like_count"]])

    # --- recent original tweets ---
    data = api(
        f"https://api.twitter.com/2/users/{UID}/tweets"
        "?max_results=40&tweet.fields=public_metrics,created_at&exclude=retweets,replies"
    ).get("data", [])
    rows = []
    new_tweets = not os.path.exists(TWEETS_CSV)
    with open(TWEETS_CSV, "a", newline="") as f:
        w = csv.writer(f)
        if new_tweets:
            w.writerow(["snapshot", "tweet_id", "created_at", "likes", "replies",
                        "retweets", "quotes", "bookmarks", "total", "text"])
        for t in data:
            m = t["public_metrics"]
            total = (m.get("like_count", 0) + m.get("reply_count", 0)
                     + m.get("retweet_count", 0) + m.get("quote_count", 0))
            text = t["text"].replace("\n", " / ")
            w.writerow([stamp, t["id"], t["created_at"], m.get("like_count", 0),
                        m.get("reply_count", 0), m.get("retweet_count", 0),
                        m.get("quote_count", 0), m.get("bookmark_count", 0),
                        total, text])
            rows.append((t["created_at"], total, m, text))

    # --- summary ---
    print(f"=== @{HANDLE} snapshot {stamp} UTC ===")
    f = prof["followers_count"]
    if prev:
        d = f - int(prev["followers"])
        print(f"followers: {f} ({'+' if d >= 0 else ''}{d} since {prev['snapshot']})")
    else:
        print(f"followers: {f} (first snapshot — baseline set)")
    print(f"following: {prof['following_count']} | total tweets: {prof['tweet_count']}")

    week_ago = now - timedelta(days=7)
    recent = [r for r in rows
              if datetime.fromisoformat(r[0].replace("Z", "+00:00")) >= week_ago]
    recent.sort(key=lambda r: r[1], reverse=True)
    print(f"\ntop originals in last 7 days ({len(recent)} posts):")
    for created, total, m, text in recent[:6]:
        print(f"  [{created[:16]}] tot{total:>3} "
              f"(L{m.get('like_count',0)} R{m.get('reply_count',0)} "
              f"RT{m.get('retweet_count',0)}) {text[:90]}")
    if recent:
        avg = sum(r[1] for r in recent) / len(recent)
        print(f"\n7-day avg engagement/original: {avg:.1f}")
    print(f"\nlogged to {TWEETS_CSV} and {ACCOUNT_CSV}")


if __name__ == "__main__":
    main()
