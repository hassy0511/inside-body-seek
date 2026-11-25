#!/usr/bin/env python3
"""エディタの Godot と ブラウザ版で 出た 行（godot/tests/web_text.gd の「WEBTEXT …」）を くらべる。
tools/web_text_check.sh が 呼ぶ。  python3 tools/web_text_compare.py <エディタの ログ> <ブラウザの ログ>
ちがいを ぜんぶ 書き、さいごに 1 行：「WEB TEXT: OK（N 画面、M 文）」か「WEB TEXT: FAILED（…）」。
見る もの：画面の 大きさ・画面の 数と 順・文ごとの 行（字）・ラベルが 数えた 行の 数・文が 切れて いるか・画面の fits()。
どちらかの ログに SCRIPT ERROR や ページの エラーが あっても FAILED（めぐりが とちゅうで こわれて いる かも しれない）。
"""
import json
import sys


notes = []


def load(path):
    recs, errors, head, end = [], [], None, None
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("WEBTEXT "):
                try:
                    r = json.loads(line[8:])
                except ValueError:
                    errors.append("読めない 行: " + line[:200])
                    continue
                if "view" in r:
                    head = r
                elif "end" in r:
                    end = r
                else:
                    recs.append(r)
            elif "SCRIPT ERROR" in line or line.startswith("TIMEOUT"):
                errors.append(line[:300])
            elif line.startswith("PAGE ERROR"):
                # ページの エラー（音の しかけなど。押す 前の ブラウザは 音を 出せない）。めぐりが さいごまで 行けば 失敗に しない
                notes.append(line[:300])
    return recs, errors, head, end


def show(lines):
    return " ／ ".join("「%s」" % s for s in lines)


def main():
    if len(sys.argv) != 3:
        print("使い方: web_text_compare.py <エディタの ログ> <ブラウザの ログ>")
        return 2
    nat, nat_err, nat_head, nat_end = load(sys.argv[1])
    web, web_err, web_head, web_end = load(sys.argv[2])
    problems = []   # めぐりが こわれた（くらべられない）
    diffs = []      # 行の ちがい
    for side, err, head, end in (("エディタ", nat_err, nat_head, nat_end), ("ブラウザ", web_err, web_head, web_end)):
        for e in err:
            problems.append("%s: %s" % (side, e))
        if head is None:
            problems.append("%s: はじめの 行（画面の 大きさ）が 無い" % side)
        if end is None:
            problems.append("%s: さいごまで 行って いない（end が 無い）" % side)
    if nat_head and web_head:
        print("エディタ: %s／データ %s／設定 %s／%s" % (nat_head.get("ts"), nat_head.get("data"), nat_head.get("setting"), nat_head.get("view")))
        print("ブラウザ: %s／データ %s／設定 %s／%s" % (web_head.get("ts"), web_head.get("data"), web_head.get("setting"), web_head.get("view")))
        if nat_head.get("view") != web_head.get("view"):
            problems.append("画面の 大きさが ちがう（エディタ %s、ブラウザ %s）" % (nat_head.get("view"), web_head.get("view")))

    def key(r):
        return (r["s"], r.get("i", -1), "fits" in r, "error" in r)

    nat_map = {key(r): r for r in nat}
    web_map = {key(r): r for r in web}
    for r in nat + web:
        if "error" in r:
            problems.append("画面 %s: %s" % (r["s"], r["error"]))
    # はかりちがい：ラベルの 行の 数と、この 道具が 出した 行の 数が 合わない（道具の まちがい。くらべても いみが ない）
    for side, recs in (("エディタ", nat), ("ブラウザ", web)):
        for r in recs:
            if "n" in r and r["n"] != len(r["lines"]):
                problems.append("%s: はかりちがい %s #%d「%s」：ラベルは %d 行、道具は %d 行" % (side, r["s"], r["i"], r["t"][:30], r["n"], len(r["lines"])))
    screens = []
    for r in nat:
        if r["s"] not in screens:
            screens.append(r["s"])
    for k in nat_map:
        if k not in web_map:
            r = nat_map[k]
            diffs.append("%s #%s: ブラウザに 無い（エディタ「%s」）" % (r["s"], r.get("i", "fits"), r.get("t", "")[:40]))
    for k in web_map:
        if k not in nat_map:
            r = web_map[k]
            diffs.append("%s #%s: エディタに 無い（ブラウザ「%s」）" % (r["s"], r.get("i", "fits"), r.get("t", "")[:40]))
    texts = 0
    bad_texts = 0
    for k, a in nat_map.items():
        b = web_map.get(k)
        if b is None:
            continue
        if "fits" in a:
            if a["fits"] != b["fits"]:
                diffs.append("%s: 画面の fits() が ちがう（エディタ %s「%s」、ブラウザ %s「%s」）" % (a["s"], a["fits"], a["over"], b["fits"], b["over"]))
            continue
        texts += 1
        msg = []
        if a["t"] != b["t"]:
            msg.append("文が ちがう（ブラウザ「%s」）" % b["t"])
        if a["lines"] != b["lines"]:
            msg.append("行が ちがう\n      エディタ %d 行: %s\n      ブラウザ %d 行: %s" % (len(a["lines"]), show(a["lines"]), len(b["lines"]), show(b["lines"])))
        if a.get("n") != b.get("n"):
            msg.append("ラベルの 行の 数（エディタ %s、ブラウザ %s）" % (a.get("n"), b.get("n")))
        if a.get("cut") != b.get("cut"):
            msg.append("切れて いるか（エディタ %s、ブラウザ %s）" % (a.get("cut"), b.get("cut")))
        if a.get("w") != b.get("w"):
            msg.append("幅（エディタ %s、ブラウザ %s）" % (a.get("w"), b.get("w")))
        if msg:
            bad_texts += 1
            diffs.append("%s #%d「%s」: %s" % (a["s"], a["i"], a["t"].replace("\n", "⏎")[:60], "；".join(msg)))
    for d in diffs:
        print("ちがい: " + d)
    for p in problems:
        print("もんだい: " + p)
    for p in notes:
        print("ちゅうい: " + p)
    n = len(screens)
    if problems or diffs:
        print("WEB TEXT: FAILED（%d 画面、%d 文。ちがう 文 %d、ほかの ちがい %d、もんだい %d）"
              % (n, texts, bad_texts, len(diffs) - bad_texts, len(problems)))
        return 1
    print("WEB TEXT: OK（%d 画面、%d 文）" % (n, texts))
    return 0


if __name__ == "__main__":
    sys.exit(main())
