#!/usr/bin/env python3
"""ブックマーク用のダッシュボードのページ（docs/dashboard.md の冒頭の URL）に入れる JSON を作る。

元にするもの：docs/dashboard.md の 1〜4・7 章、godot/src/autoload/stage_db.gd、テストのログ（あれば）。
    python3 tools/dashboard_data.py --out /tmp/dash --test-log /tmp/inside-body-seek-test.log
出力：phases / todo / art / models / stages / prompts の .json（行の配列）。
"""
import argparse
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent


def sections(md: str) -> dict:
    """「## 1. 題」ごとに本文を分ける。キーは番号。"""
    out = {}
    for m in re.finditer(r"^## (\d+)\. .*?$(.*?)(?=^## |\Z)", md, re.M | re.S):
        out[int(m.group(1))] = m.group(2)
    return out


def clean(cell: str) -> str:
    return cell.replace("**", "").replace("`", "").strip()


def first_table(text: str) -> list:
    """本文の最初の表を行の辞書の配列にする。"""
    rows = []
    for l in text.splitlines():
        if l.startswith("|"):
            rows.append(l)
        elif rows:
            break
    if len(rows) < 2:
        return []
    split = lambda l: [clean(c) for c in l.strip().strip("|").split("|")]
    head = split(rows[0])
    return [dict(zip(head, split(r))) for r in rows[2:]]


def prompts(text: str) -> list:
    return [{"題": m.group(1).strip(), "文": m.group(2).strip()}
            for m in re.finditer(r"^### (.+?)\n+```text\n(.*?)```", text, re.M | re.S)]


def stages(gd: str, test_log: str) -> list:
    cleared = {m.group(1): float(m.group(2))
               for m in re.finditer(r"cleared (\w+) in ([\d.]+)s \(sim\)", test_log)}
    ok = "RESULT: OK" in test_log
    kinds = {"arena": "ひろば", "tube": "くだ", "rooms": "へや"}
    out = []
    # 1 ステージ = 「"id": ...」から次の「"id":」まで
    blocks = re.split(r'\n\t\t"id": ', gd)[1:]
    for b in blocks:
        g = lambda key: re.search(r'"%s": "?([^",]*)"?' % key, '"id": ' + b).group(1)
        missions = []
        for m in re.finditer(r'\{"type": "\w+"(.*?)"text": "([^"]*)"\}', b.split('"intro"')[0]):
            n = re.search(r'"count": (\d+)', m.group(1))
            missions.append(m.group(2) + ("（%s）" % n.group(1) if n else ""))
        sid = g("id")
        test = "—"
        if test_log:
            test = "OK（%.0f 秒）" % cleared[sid] if sid in cleared else "クリアできず"
        out.append({
            "順": int(g("order")), "ステージ": "%s（%s）" % (g("name"), g("kanji")), "題": g("title"),
            "形": kinds.get(g("kind"), g("kind")), "むずかしさ": "★" * int(g("difficulty")),
            "ミッション": " → ".join(missions), "自動テスト": test,
        })
    if test_log and not ok:
        for s in out:
            s["自動テスト"] += "（テスト全体は失敗）"
    return sorted(out, key=lambda s: s["順"])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--test-log", default="")
    a = ap.parse_args()
    md = (ROOT / "docs/dashboard.md").read_text(encoding="utf-8")
    gd = (ROOT / "godot/src/autoload/stage_db.gd").read_text(encoding="utf-8")
    log = pathlib.Path(a.test_log).read_text(encoding="utf-8", errors="replace") if a.test_log else ""
    sec = sections(md)
    data = {
        "phases": first_table(sec[1]),
        "todo": first_table(sec[2]),
        "art": first_table(sec[3]),
        "models": first_table(sec[4]),
        "stages": stages(gd, log),
        "prompts": prompts(sec[7]),
    }
    out = pathlib.Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    for name, rows in data.items():
        assert rows, "%s が空（dashboard.md の章の形を確かめる）" % name
        (out / ("%s.json" % name)).write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
        print("%-8s %2d 行" % (name, len(rows)))


if __name__ == "__main__":
    main()
