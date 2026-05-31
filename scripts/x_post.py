#!/usr/bin/env python3
"""Post a tweet to @itsmehatef via the X API v2 using OAuth 1.0a user context.

Usage:
  python3 scripts/x_post.py --file path/to/tweet.txt
  echo "tweet text" | python3 scripts/x_post.py
On success prints the tweet id + URL. Reads the 4 OAuth creds from env.
"""
import os, sys, time, hmac, hashlib, base64, urllib.parse, urllib.request, urllib.error, secrets, json, argparse

CK = os.environ["X_API_KEY"]; CS = os.environ["X_API_SECRET"]
AT = os.environ["X_ACCESS_TOKEN"]; ATS = os.environ["X_ACCESS_TOKEN_SECRET"]
enc = lambda s: urllib.parse.quote(str(s), safe="~")


def oauth_header(method, url):
    o = {"oauth_consumer_key": CK, "oauth_nonce": secrets.token_hex(16),
         "oauth_signature_method": "HMAC-SHA1", "oauth_timestamp": str(int(time.time())),
         "oauth_token": AT, "oauth_version": "1.0"}
    base = "&".join(f"{enc(k)}={enc(o[k])}" for k in sorted(o))
    sb = "&".join([method, enc(url), enc(base)])
    key = f"{enc(CS)}&{enc(ATS)}"
    o["oauth_signature"] = base64.b64encode(
        hmac.new(key.encode(), sb.encode(), hashlib.sha1).digest()).decode()
    return "OAuth " + ", ".join(f'{enc(k)}="{enc(v)}"' for k, v in sorted(o.items()))


def post(text):
    url = "https://api.twitter.com/2/tweets"
    body = json.dumps({"text": text}).encode()
    req = urllib.request.Request(
        url, data=body, method="POST",
        headers={"Authorization": oauth_header("POST", url),
                 "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", help="read tweet text from file; otherwise stdin")
    args = ap.parse_args()
    text = open(args.file).read() if args.file else sys.stdin.read()
    text = text.rstrip("\n")
    if not text.strip():
        print("empty tweet text", file=sys.stderr); sys.exit(1)
    if len(text) > 280:
        print(f"tweet is {len(text)} chars (>280)", file=sys.stderr); sys.exit(1)
    try:
        res = post(text)
        tid = res["data"]["id"]
        print(f"posted: https://x.com/itsmehatef/status/{tid}")
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, e.read().decode()[:500], file=sys.stderr); sys.exit(1)


if __name__ == "__main__":
    main()
